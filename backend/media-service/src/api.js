'use strict';

const express = require('express');
const logger = require('./logger');
const mediasoupManager = require('./mediasoup-manager');
const transportManager = require('./transport-manager');
const producerConsumerManager = require('./producer-consumer-manager');
const recordingManager = require('./recording-manager');

const router = express.Router();

// ── Helper: async error handler ──────────────────────────
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

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
 * Room'u kapatır.
 */
router.delete(
  '/rooms/:roomId',
  asyncHandler(async (req, res) => {
    const { roomId } = req.params;
    mediasoupManager.closeRoom(roomId);
    res.status(204).send();
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
 * Server-side recording başlatır.
 */
router.post(
  '/rooms/:roomId/recording/start',
  asyncHandler(async (req, res) => {
    const { roomId } = req.params;
    await recordingManager.startRecording(roomId);
    res.status(201).json({ recording: true, roomId });
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
