'use strict';

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const config = require('./config');
const logger = require('./logger');
const mediasoupManager = require('./mediasoup-manager');
const transportManager = require('./transport-manager');
const producerConsumerManager = require('./producer-consumer-manager');
const s3Uploader = require('./s3-uploader');
const kafkaPublisher = require('./kafka-publisher');
const { v4: uuidv4 } = require('uuid');

/**
 * Server-side recording yönetimi.
 *
 * PlainTransport üzerinden RTP akışını FFmpeg'e yönlendirir,
 * FFmpeg stream copy ile .webm dosyasına kaydeder.
 * Kayıt tamamlanınca dosyayı S3'e yükler.
 *
 * Pending recording: startRecording çağrıldığında producer'lar henüz
 * hazır değilse "pending" işaretlenir. ProducerConsumerManager'dan
 * gelen 'producerCreated' eventi ile producer'lar hazır olduğunda
 * otomatik başlatılır. Bu sayede signaling tarafı (interview-service)
 * peer'lar room'a girer girmez recording isteyebilir; media plane
 * hazır olur olmaz pipeline gerçekten başlar.
 */
class RecordingManager {
  constructor() {
    /**
     * roomId → { process, segmentDir, segmentPattern, transports, consumers, uploadedSegments, uploadTimer }
     * @type {Map<string, object>}
     */
    this.activeRecordings = new Map();

    /**
     * Producer'ları bekleyen pending recording'ler.
     * @type {Set<string>}
     */
    this.pendingRecordings = new Set();

    // Producer hazır olduğunda pending recording'i başlatmayı dene.
    producerConsumerManager.on('producerCreated', ({ roomId }) => {
      this._tryStartPending(roomId).catch((err) => {
        logger.warn(`Pending recording start denemesi başarısız: ${roomId} → ${err.message}`);
      });
    });
  }

  /**
   * Belirtilen room için recording başlatır.
   *
   * Producer'lar (audio + video) hazırsa hemen başlar; değilse pending
   * olarak işaretlenir ve producer geldiğinde otomatik başlatılır.
   *
   * @param {string} roomId
   * @returns {Promise<{ status: 'active'|'pending' }>}
   */
  async startRecording(roomId) {
    if (this.activeRecordings.has(roomId)) {
      logger.info(`Room zaten kaydediliyor (idempotent): ${roomId}`);
      return { status: 'active' };
    }

    if (this.pendingRecordings.has(roomId)) {
      logger.info(`Room recording pending (idempotent): ${roomId}`);
      return { status: 'pending' };
    }

    const router = mediasoupManager.getRouter(roomId);
    if (!router) {
      throw new Error(`Room bulunamadı: ${roomId}`);
    }

    if (this._hasRequiredProducers(roomId)) {
      await this._doStartRecording(roomId);
      return { status: 'active' };
    }

    this.pendingRecordings.add(roomId);
    logger.info(`Recording pending (producer'lar bekleniyor): ${roomId}`);
    return { status: 'pending' };
  }

  /**
   * Room için audio + video producer'ları hazır mı kontrol eder.
   * @private
   */
  _hasRequiredProducers(roomId) {
    const producers = producerConsumerManager.getProducersByRoom(roomId);
    const hasAudio = producers.some((p) => p.kind === 'audio');
    const hasVideo = producers.some((p) => p.kind === 'video');
    return hasAudio && hasVideo;
  }

  /**
   * Pending bir recording'i başlatmayı dener; producer'lar hazır değilse
   * sessizce return eder. Producer hazır olunca event ile tetiklenir.
   * @private
   */
  async _tryStartPending(roomId) {
    if (!this.pendingRecordings.has(roomId)) {
      return;
    }
    if (this.activeRecordings.has(roomId)) {
      this.pendingRecordings.delete(roomId);
      return;
    }
    if (!this._hasRequiredProducers(roomId)) {
      return;
    }

    // Önce pending'den çıkar; başlatma fail olursa geri ekle.
    this.pendingRecordings.delete(roomId);
    try {
      await this._doStartRecording(roomId);
      logger.info(`Pending recording otomatik başlatıldı: ${roomId}`);
    } catch (err) {
      this.pendingRecordings.add(roomId);
      throw err;
    }
  }

  /**
   * Asıl recording pipeline'ını kurar (PlainTransport + Consumer + FFmpeg).
   * Bu metoda girmeden önce producer'ların hazır olduğu garantilenmelidir.
   * @private
   */
  async _doStartRecording(roomId) {
    const router = mediasoupManager.getRouter(roomId);
    if (!router) {
      throw new Error(`Room bulunamadı: ${roomId}`);
    }

    // Çıktı dizinini oluştur
    const outputDir = config.recording.outputDir;
    fs.mkdirSync(outputDir, { recursive: true });

    const startedAt = Date.now();
    const segmentDir = path.join(outputDir, roomId, String(startedAt));
    fs.mkdirSync(segmentDir, { recursive: true });
    const segmentPattern = path.join(segmentDir, '%06d.webm');

    // Sadece bu room'a ait producer'ları al — global Map'ten DEĞİL.
    const producers = producerConsumerManager.getProducersByRoom(roomId);
    if (producers.length === 0) {
      throw new Error(`Room'da aktif producer yok: ${roomId}`);
    }

    // Her producer için PlainTransport + Consumer oluştur
    const recordingState = {
      process: null,
      roomId,
      startedAt,
      segmentDir,
      segmentPattern,
      transports: [],
      consumers: [],
      uploadedSegments: new Set(),
      uploadedUrls: [],
      uploadTimer: null,
    };

    const audioProducer = producers.find((p) => p.kind === 'audio');
    const videoProducer = producers.find((p) => p.kind === 'video');

    let audioTransportInfo = null;
    let videoTransportInfo = null;

    if (audioProducer) {
      const plainTransport = await transportManager.createPlainTransport(roomId);
      const transport = transportManager.getTransport(plainTransport.id);

      const consumer = await transport.consume({
        producerId: audioProducer.id,
        rtpCapabilities: router.rtpCapabilities,
        paused: false,
      });

      audioTransportInfo = {
        ip: plainTransport.ip,
        port: plainTransport.port,
        rtcpPort: plainTransport.rtcpPort,
        payloadType: consumer.rtpParameters.codecs[0].payloadType,
        clockRate: consumer.rtpParameters.codecs[0].clockRate,
        channels: consumer.rtpParameters.codecs[0].channels || 2,
      };

      recordingState.transports.push(plainTransport.id);
      recordingState.consumers.push(consumer);
    }

    if (videoProducer) {
      const plainTransport = await transportManager.createPlainTransport(roomId);
      const transport = transportManager.getTransport(plainTransport.id);

      const consumer = await transport.consume({
        producerId: videoProducer.id,
        rtpCapabilities: router.rtpCapabilities,
        paused: false,
      });

      videoTransportInfo = {
        ip: plainTransport.ip,
        port: plainTransport.port,
        rtcpPort: plainTransport.rtcpPort,
        payloadType: consumer.rtpParameters.codecs[0].payloadType,
        clockRate: consumer.rtpParameters.codecs[0].clockRate,
      };

      recordingState.transports.push(plainTransport.id);
      recordingState.consumers.push(consumer);
    }

    // SDP dosyası oluştur
    const sdpContent = this._buildSdp(audioTransportInfo, videoTransportInfo);
    const sdpFile = path.join(segmentDir, `${roomId}.sdp`);
    fs.writeFileSync(sdpFile, sdpContent);

    logger.info(`Recording SDP oluşturuldu: ${sdpFile}`);

    // FFmpeg spawn et
    const ffmpegArgs = [
      '-protocol_whitelist', 'file,rtp,udp',
      '-fflags', '+genpts',
      '-i', sdpFile,
      '-c', 'copy',
      '-flags', '+global_header',
      '-f', 'segment',
      '-segment_time', String(config.recording.segmentSeconds),
      '-reset_timestamps', '1',
      '-segment_format', config.recording.format,
      '-y',
      segmentPattern,
    ];

    logger.info(`FFmpeg başlatılıyor: ffmpeg ${ffmpegArgs.join(' ')}`);

    const ffmpegProcess = spawn('ffmpeg', ffmpegArgs, {
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    ffmpegProcess.stderr.on('data', (data) => {
      logger.debug(`FFmpeg [${roomId}]: ${data.toString().trim()}`);
    });

    ffmpegProcess.on('error', (err) => {
      logger.error(`FFmpeg hata: ${roomId}`, { error: err.message });
    });

    ffmpegProcess.on('close', (code) => {
      logger.info(`FFmpeg kapandı: ${roomId} (code=${code})`);
    });

    recordingState.process = ffmpegProcess;
    recordingState.uploadTimer = setInterval(() => {
      this._uploadClosedSegments(roomId, false).catch((err) => {
        logger.warn(`Segment upload döngüsü başarısız: ${roomId} → ${err.message}`);
      });
    }, 2000);
    this.activeRecordings.set(roomId, recordingState);

    logger.info(`Segmentli recording başladı: ${roomId} → ${segmentPattern}`);
  }

  /**
   * Recording'i durdurur, FFmpeg'i kapatır ve S3'e yükler.
   *
   * İdempotenttir:
   *   - Aktif recording yoksa, pending varsa onu temizler ve null döner.
   *   - Tamamen yoksa null döner (hata atmaz). Bu sayede completion
   *     flow'u hem WebSocket FINISH_DONE hem REST /complete üzerinden
   *     güvenle çağrılabilir.
   *
   * @param {string} roomId
   * @returns {Promise<string|null>} Kaydedilen dosyanın S3 URL'si veya null
   */
  async stopRecording(roomId) {
    const recording = this.activeRecordings.get(roomId);
    if (!recording) {
      if (this.pendingRecordings.delete(roomId)) {
        logger.info(`Pending recording iptal edildi (henüz başlamamıştı): ${roomId}`);
      } else {
        logger.debug(`stopRecording no-op (aktif/pending recording yok): ${roomId}`);
      }
      return null;
    }

    // FFmpeg'e graceful shutdown sinyali gönder
    if (recording.process && !recording.process.killed) {
      recording.process.stdin.write('q');
      recording.process.stdin.end();

      // FFmpeg'in kapanmasını bekle (max 10 saniye)
      await new Promise((resolve) => {
        const timeout = setTimeout(() => {
          if (!recording.process.killed) {
            recording.process.kill('SIGKILL');
          }
          resolve();
        }, 10000);

        recording.process.on('close', () => {
          clearTimeout(timeout);
          resolve();
        });
      });
    }

    if (recording.uploadTimer) {
      clearInterval(recording.uploadTimer);
      recording.uploadTimer = null;
    }

    // Consumer'ları kapat
    for (const consumer of recording.consumers) {
      consumer.close();
    }

    // PlainTransport'ları kapat
    for (const transportId of recording.transports) {
      transportManager.closeTransport(transportId);
    }

    this.activeRecordings.delete(roomId);

    await this._uploadClosedSegments(roomId, true, recording);

    // SDP dosyasını temizle
    const sdpFile = path.join(recording.segmentDir, `${roomId}.sdp`);
    if (fs.existsSync(sdpFile)) {
      fs.unlinkSync(sdpFile);
    }

    const manifest = await this._uploadManifest(recording);
    try {
      fs.rmSync(recording.segmentDir, { recursive: true, force: true });
    } catch (err) {
      logger.debug(`Segment dizini temizlenemedi: ${recording.segmentDir} → ${err.message}`);
    }

    logger.info(`Recording durduruldu: ${roomId}${manifest ? ` → ${manifest}` : ''}`);
    return manifest;
  }

  async _uploadClosedSegments(roomId, includeLast = false, explicitRecording = null) {
    const recording = explicitRecording || this.activeRecordings.get(roomId);
    if (!recording || !fs.existsSync(recording.segmentDir)) {
      return;
    }

    const files = fs.readdirSync(recording.segmentDir)
      .filter((file) => file.endsWith('.webm'))
      .sort();
    const candidates = includeLast ? files : files.slice(0, Math.max(0, files.length - 1));

    for (const file of candidates) {
      if (recording.uploadedSegments.has(file)) {
        continue;
      }

      const filePath = path.join(recording.segmentDir, file);
      const stats = fs.statSync(filePath);
      if (stats.size === 0) {
        continue;
      }
      if (!includeLast && Date.now() - stats.mtimeMs < 1500) {
        continue;
      }

      const segmentIndex = parseInt(path.basename(file, '.webm'), 10);
      const startSecond = segmentIndex * config.recording.segmentSeconds;
      const endSecond = startSecond + config.recording.segmentSeconds;
      const rangeName = `${this._padSecond(startSecond)}-${this._padSecond(endSecond)}.webm`;
      const s3Key = `recordings/${roomId}/${rangeName}`;
      const url = await s3Uploader.upload(filePath, s3Key);

      const uploadedAt = new Date().toISOString();
      const segmentInfo = {
        event_id: `evt-${uuidv4()}`,
        timestamp: uploadedAt,
        session_id: roomId,
        segment_index: segmentIndex,
        start_second: startSecond,
        end_second: endSecond,
        duration_seconds: config.recording.segmentSeconds,
        recorded_video_url: url,
        s3_key: s3Key,
      };

      recording.uploadedSegments.add(file);
      recording.uploadedUrls.push(segmentInfo);
      await kafkaPublisher.publishRecordingSegment(segmentInfo);

      fs.unlinkSync(filePath);
      logger.info(`Recording segment MinIO'ya yüklendi: ${roomId} ${startSecond}-${endSecond}s`);
    }
  }

  async _uploadManifest(recording) {
    if (!recording.uploadedUrls.length) {
      return null;
    }
    const manifest = {
      sessionId: recording.roomId,
      segmentSeconds: config.recording.segmentSeconds,
      segments: recording.uploadedUrls,
      createdAt: new Date().toISOString(),
    };
    const key = `recordings/${recording.roomId}/manifest.json`;
    return s3Uploader.uploadBuffer(Buffer.from(JSON.stringify(manifest, null, 2)), key, 'application/json');
  }

  _padSecond(second) {
    return String(second).padStart(6, '0');
  }

  /**
   * FFmpeg için SDP dosyası oluşturur.
   * @param {object|null} audio Audio transport bilgisi
   * @param {object|null} video Video transport bilgisi
   * @returns {string} SDP içeriği
   */
  _buildSdp(audio, video) {
    let sdp = 'v=0\n';
    sdp += 'o=- 0 0 IN IP4 127.0.0.1\n';
    sdp += 's=Internview Recording\n';
    sdp += 'c=IN IP4 127.0.0.1\n';
    sdp += 't=0 0\n';

    if (audio) {
      sdp += `m=audio ${audio.port} RTP/AVP ${audio.payloadType}\n`;
      sdp += `a=rtpmap:${audio.payloadType} opus/${audio.clockRate}/${audio.channels}\n`;
      sdp += `a=fmtp:${audio.payloadType} minptime=10;useinbandfec=1\n`;
    }

    if (video) {
      sdp += `m=video ${video.port} RTP/AVP ${video.payloadType}\n`;
      sdp += `a=rtpmap:${video.payloadType} VP8/${video.clockRate}\n`;
    }

    return sdp;
  }

  /**
   * Belirtilen room'un AKTİF recording durumunda olup olmadığını kontrol eder.
   * Pending recording'leri içermez.
   * @param {string} roomId
   * @returns {boolean}
   */
  isRecording(roomId) {
    return this.activeRecordings.has(roomId);
  }

  /**
   * Room için bir recording rezervasyonu (aktif veya pending) var mı?
   * Room kapatma/orphan safety akışında kullanılır.
   * @param {string} roomId
   * @returns {boolean}
   */
  hasReservation(roomId) {
    return this.activeRecordings.has(roomId) || this.pendingRecordings.has(roomId);
  }
}

const recordingManager = new RecordingManager();
module.exports = recordingManager;
