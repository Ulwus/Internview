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

/**
 * Server-side recording yönetimi.
 *
 * PlainTransport üzerinden RTP akışını FFmpeg'e yönlendirir,
 * FFmpeg stream copy ile .webm dosyasına kaydeder.
 * Kayıt tamamlanınca dosyayı S3'e yükler.
 */
class RecordingManager {
  constructor() {
    /**
     * roomId → { process, filePath, audioConsumer, videoConsumer,
     *            audioTransport, videoTransport }
     * @type {Map<string, object>}
     */
    this.activeRecordings = new Map();
  }

  /**
   * Belirtilen room için recording başlatır.
   *
   * Adımlar:
   * 1. Audio ve video producer'larını bul
   * 2. PlainTransport oluştur (her biri için)
   * 3. Consumer oluştur → PlainTransport'a bağla
   * 4. SDP dosyası oluştur
   * 5. FFmpeg spawn et
   *
   * @param {string} roomId
   * @returns {Promise<void>}
   */
  async startRecording(roomId) {
    if (this.activeRecordings.has(roomId)) {
      logger.warn(`Room zaten kaydediliyor: ${roomId}`);
      return;
    }

    const router = mediasoupManager.getRouter(roomId);
    if (!router) {
      throw new Error(`Room bulunamadı: ${roomId}`);
    }

    // Çıktı dizinini oluştur
    const outputDir = config.recording.outputDir;
    fs.mkdirSync(outputDir, { recursive: true });

    const timestamp = Date.now();
    const outputFile = path.join(outputDir, `${roomId}_${timestamp}.webm`);

    // Room'daki producer'ları bul
    const producers = [];
    for (const [, producer] of producerConsumerManager.producers) {
      producers.push(producer);
    }

    if (producers.length === 0) {
      throw new Error(`Room'da aktif producer yok: ${roomId}`);
    }

    // Her producer için PlainTransport + Consumer oluştur
    const recordingState = {
      process: null,
      filePath: outputFile,
      transports: [],
      consumers: [],
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
    const sdpFile = path.join(outputDir, `${roomId}_${timestamp}.sdp`);
    fs.writeFileSync(sdpFile, sdpContent);

    logger.info(`Recording SDP oluşturuldu: ${sdpFile}`);

    // FFmpeg spawn et
    const ffmpegArgs = [
      '-protocol_whitelist', 'file,rtp,udp',
      '-fflags', '+genpts',
      '-i', sdpFile,
      '-c', 'copy',
      '-flags', '+global_header',
      '-y',
      outputFile,
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
    this.activeRecordings.set(roomId, recordingState);

    logger.info(`Recording başladı: ${roomId} → ${outputFile}`);
  }

  /**
   * Recording'i durdurur, FFmpeg'i kapatır ve S3'e yükler.
   * @param {string} roomId
   * @returns {Promise<string>} Kaydedilen dosyanın S3 URL'si
   */
  async stopRecording(roomId) {
    const recording = this.activeRecordings.get(roomId);
    if (!recording) {
      throw new Error(`Aktif recording bulunamadı: ${roomId}`);
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

    // Consumer'ları kapat
    for (const consumer of recording.consumers) {
      consumer.close();
    }

    // PlainTransport'ları kapat
    for (const transportId of recording.transports) {
      transportManager.closeTransport(transportId);
    }

    this.activeRecordings.delete(roomId);

    // S3'e yükle
    let s3Url = null;
    if (fs.existsSync(recording.filePath)) {
      const fileStats = fs.statSync(recording.filePath);
      if (fileStats.size > 0) {
        const timestamp = Date.now();
        const s3Key = `recordings/${roomId}/${timestamp}.webm`;
        s3Url = await s3Uploader.upload(recording.filePath, s3Key);

        // Local dosyayı temizle
        fs.unlinkSync(recording.filePath);
        logger.info(`Local recording dosyası silindi: ${recording.filePath}`);
      } else {
        logger.warn(`Recording dosyası boş: ${recording.filePath}`);
        fs.unlinkSync(recording.filePath);
      }
    }

    // SDP dosyasını temizle
    const sdpFile = recording.filePath.replace('.webm', '.sdp');
    if (fs.existsSync(sdpFile)) {
      fs.unlinkSync(sdpFile);
    }

    logger.info(`Recording durduruldu: ${roomId}${s3Url ? ` → ${s3Url}` : ''}`);
    return s3Url;
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
   * Belirtilen room'un recording durumunda olup olmadığını kontrol eder.
   * @param {string} roomId
   * @returns {boolean}
   */
  isRecording(roomId) {
    return this.activeRecordings.has(roomId);
  }
}

const recordingManager = new RecordingManager();
module.exports = recordingManager;
