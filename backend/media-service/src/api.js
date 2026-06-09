'use strict';

const express = require('express');
const logger = require('./logger');
const mediasoupManager = require('./mediasoup-manager');
const transportManager = require('./transport-manager');
const producerConsumerManager = require('./producer-consumer-manager');
const recordingManager = require('./recording-manager');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const s3Uploader = require('./s3-uploader');

const router = express.Router();

// ── Helper: async error handler ──────────────────────────
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 }, // 8MB
});

/**
 * POST /uploads/avatar
 * form-data: file
 * returns: { url, key }
 */
router.post(
  '/uploads/avatar',
  upload.single('file'),
  asyncHandler(async (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'file gerekli' });

    const contentType = req.file.mimetype || 'application/octet-stream';
    const ext = contentType === 'image/png' ? 'png' : 'jpg';
    const key = `avatars/${Date.now()}-${uuidv4()}.${ext}`;

    await s3Uploader.uploadBuffer(req.file.buffer, key, contentType);
    const url = `${req.protocol}://${req.get('host')}/media/files/${encodeURIComponent(key)}`;
    res.status(201).json({ url, key });
  })
);

/**
 * GET /files/:key
 * Not: key path param URL-encoded olmalı (örn: avatars%2F...jpg).
 */
router.get(
  '/files/:key',
  asyncHandler(async (req, res) => {
    const key = decodeURIComponent(req.params.key || '');
    if (!key) return res.status(400).json({ error: 'key gerekli' });

    const obj = await s3Uploader.getObject(key);
    if (obj.ContentType) res.setHeader('Content-Type', obj.ContentType);
    if (obj.ContentLength != null) res.setHeader('Content-Length', String(obj.ContentLength));
    res.setHeader('Cache-Control', 'public, max-age=3600');

    // AWS SDK v3: Body bir stream (Node.js Readable)
    if (!obj.Body) return res.status(404).json({ error: 'Dosya bulunamadı' });
    obj.Body.pipe(res);
  })
);

// ── Room (Router) Endpoints ──────────────────────────────

/**
 * POST /rooms
 * Room (Router) oluşturur.
 * Body: { roomId: string }
 */
router.post(
  '/rooms',
  asyncHandler(async (req, res) => {
    const { roomId } = req.body;
    if (!roomId) {
      return res.status(400).json({ error: 'roomId gerekli' });
    }

    const routerObj = await mediasoupManager.createRoom(roomId);
    res.status(201).json({
      roomId,
      rtpCapabilities: routerObj.rtpCapabilities,
    });
  })
);

/**
 * GET /rooms/:roomId/router-capabilities
 * Router'ın RTP capabilities bilgisini döndürür.
 */
router.get(
  '/rooms/:roomId/router-capabilities',
  asyncHandler(async (req, res) => {
    const { roomId } = req.params;
    const routerObj = mediasoupManager.getRouter(roomId);
    if (!routerObj) {
      return res.status(404).json({ error: `Room bulunamadı: ${roomId}` });
    }
    res.json({ rtpCapabilities: routerObj.rtpCapabilities });
  })
);

/**
 * DELETE /rooms/:roomId
 * Room'u kapatır. Aktif recording varsa önce durdurup MinIO'ya yükler;
 * yanıt gövdesinde { closed: true, recordedVideoUrl } döndürür.
 *
 * Bu, "interview-service /complete'i çağırmadan room kapatıldı"
 * senaryosunda da kayıt kaybını önler (orphan recording güvenlik ağı).
 */
router.delete(
  '/rooms/:roomId',
  asyncHandler(async (req, res) => {
    const { roomId } = req.params;

    // Aktif veya pending recording varsa stop et (idempotent; hata atmaz).
    let recordedVideoUrl = null;
    if (recordingManager.hasReservation(roomId)) {
      try {
        recordedVideoUrl = await recordingManager.stopRecording(roomId);
        if (recordedVideoUrl) {
          logger.info(`Room close sırasında recording durduruldu: ${roomId} → ${recordedVideoUrl}`);
        } else {
          logger.info(`Room close: pending recording iptal edildi: ${roomId}`);
        }
      } catch (err) {
        logger.warn(`Room close: recording durdurulamadı: ${roomId} → ${err.message}`);
      }
    }

    mediasoupManager.closeRoom(roomId);
    res.status(200).json({ roomId, closed: true, recordedVideoUrl });
  })
);

// ── Transport Endpoints ──────────────────────────────────

/**
 * POST /rooms/:roomId/transports
 * WebRtcTransport oluşturur.
 */
router.post(
  '/rooms/:roomId/transports',
  asyncHandler(async (req, res) => {
    const { roomId } = req.params;
    const transportInfo = await transportManager.createWebRtcTransport(roomId);
    res.status(201).json(transportInfo);
  })
);

/**
 * POST /transports/:transportId/connect
 * WebRtcTransport'u bağlar (DTLS handshake).
 * Body: { dtlsParameters: object }
 */
router.post(
  '/transports/:transportId/connect',
  asyncHandler(async (req, res) => {
    const { transportId } = req.params;
    const { dtlsParameters } = req.body;
    if (!dtlsParameters) {
      return res.status(400).json({ error: 'dtlsParameters gerekli' });
    }
    await transportManager.connectTransport(transportId, dtlsParameters);
    res.json({ connected: true });
  })
);

// ── Producer / Consumer Endpoints ────────────────────────

/**
 * POST /transports/:transportId/produce
 * Producer oluşturur.
 * Body: { kind: 'audio'|'video', rtpParameters: object }
 */
router.post(
  '/transports/:transportId/produce',
  asyncHandler(async (req, res) => {
    const { transportId } = req.params;
    const { kind, rtpParameters } = req.body;
    if (!kind || !rtpParameters) {
      return res.status(400).json({ error: 'kind ve rtpParameters gerekli' });
    }
    const producerInfo = await producerConsumerManager.produce(
      transportId,
      kind,
      rtpParameters
    );
    res.status(201).json(producerInfo);
  })
);

/**
 * GET /rooms/:roomId/producers
 * Room'daki producer özetlerini döndürür.
 */
router.get(
  '/rooms/:roomId/producers',
  asyncHandler(async (req, res) => {
    const { roomId } = req.params;
    const routerObj = mediasoupManager.getRouter(roomId);
    if (!routerObj) {
      return res.status(404).json({ error: `Room bulunamadı: ${roomId}` });
    }
    res.json({ producers: producerConsumerManager.listProducerSummaries(roomId) });
  })
);

/**
 * POST /transports/:transportId/consume
 * Consumer oluşturur.
 * Body: { roomId: string, producerId: string, rtpCapabilities: object }
 */
router.post(
  '/transports/:transportId/consume',
  asyncHandler(async (req, res) => {
    const { transportId } = req.params;
    const { roomId, producerId, rtpCapabilities } = req.body;
    if (!roomId || !producerId || !rtpCapabilities) {
      return res
        .status(400)
        .json({ error: 'roomId, producerId ve rtpCapabilities gerekli' });
    }
    const consumerInfo = await producerConsumerManager.consume(
      roomId,
      transportId,
      producerId,
      rtpCapabilities
    );
    res.status(201).json(consumerInfo);
  })
);

/**
 * POST /consumers/:consumerId/resume
 * Consumer'ı resume eder.
 */
router.post(
  '/consumers/:consumerId/resume',
  asyncHandler(async (req, res) => {
    const { consumerId } = req.params;
    await producerConsumerManager.resumeConsumer(consumerId);
    res.json({ resumed: true });
  })
);

// ── Recording Endpoints ──────────────────────────────────

/**
 * POST /rooms/:roomId/recording/start
 * Server-side recording başlatır. Producer'lar henüz hazır değilse
 * pending olarak işaretlenir; producer geldiğinde otomatik başlar.
 *
 * Yanıt: { recording: true, roomId, status: 'active'|'pending' }
 */
router.post(
  '/rooms/:roomId/recording/start',
  asyncHandler(async (req, res) => {
    const { roomId } = req.params;
    const result = await recordingManager.startRecording(roomId);
    res.status(201).json({ recording: true, roomId, status: result.status });
  })
);

/**
 * POST /rooms/:roomId/recording/stop
 * Server-side recording durdurur ve S3'e yükler.
 */
router.post(
  '/rooms/:roomId/recording/stop',
  asyncHandler(async (req, res) => {
    const { roomId } = req.params;
    const recordedVideoUrl = await recordingManager.stopRecording(roomId);
    res.json({ recording: false, roomId, recordedVideoUrl });
  })
);

module.exports = router;
