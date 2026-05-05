'use strict';

const os = require('os');

/**
 * Mediasoup SFU yapılandırması.
 *
 * Tüm değerler environment variable'lardan okunur;
 * .env.example dosyasında varsayılan değerler tanımlıdır.
 */
const config = {
  // ── HTTP Server ─────────────────────────────────────
  server: {
    port: parseInt(process.env.PORT, 10) || 3000,
    logLevel: process.env.LOG_LEVEL || 'info',
  },

  // ── Mediasoup ───────────────────────────────────────
  mediasoup: {
    // Worker sayısı — belirtilmezse CPU çekirdek sayısı kadar
    numWorkers: parseInt(process.env.MEDIASOUP_NUM_WORKERS, 10) || os.cpus().length,

    worker: {
      logLevel: process.env.MEDIASOUP_LOG_LEVEL || 'warn',
      logTags: ['info', 'ice', 'dtls', 'rtp', 'srtp', 'rtcp'],
      rtcMinPort: parseInt(process.env.MEDIASOUP_MIN_PORT, 10) || 40000,
      rtcMaxPort: parseInt(process.env.MEDIASOUP_MAX_PORT, 10) || 40099,
    },

    // Router desteklenen medya codec'leri
    router: {
      mediaCodecs: [
        {
          kind: 'audio',
          mimeType: 'audio/opus',
          clockRate: 48000,
          channels: 2,
        },
        {
          kind: 'video',
          mimeType: 'video/VP8',
          clockRate: 90000,
          parameters: {
            'x-google-start-bitrate': 1000,
          },
        },
        {
          kind: 'video',
          mimeType: 'video/VP9',
          clockRate: 90000,
          parameters: {
            'profile-id': 2,
            'x-google-start-bitrate': 1000,
          },
        },
        {
          kind: 'video',
          mimeType: 'video/H264',
          clockRate: 90000,
          parameters: {
            'packetization-mode': 1,
            'profile-level-id': '4d0032',
            'level-asymmetry-allowed': 1,
            'x-google-start-bitrate': 1000,
          },
        },
      ],
    },

    // WebRTC Transport ayarları
    webRtcTransport: {
      listenIps: [
        {
          ip: process.env.MEDIASOUP_LISTEN_IP || '0.0.0.0',
          announcedIp: process.env.MEDIASOUP_ANNOUNCED_IP || '127.0.0.1',
        },
      ],
      maxIncomingBitrate: 1500000,
      initialAvailableOutgoingBitrate: 1000000,
    },

    // PlainTransport ayarları (recording için)
    plainTransport: {
      listenIp: {
        ip: process.env.MEDIASOUP_LISTEN_IP || '0.0.0.0',
        announcedIp: process.env.MEDIASOUP_ANNOUNCED_IP || '127.0.0.1',
      },
      rtcpMux: false, // FFmpeg rtcp-mux desteklemez
      comedia: false,
    },
  },

  // ── S3 (MinIO uyumlu) ──────────────────────────────
  s3: {
    endpoint: process.env.S3_ENDPOINT || 'http://localhost:9000',
    region: process.env.S3_REGION || 'us-east-1',
    accessKeyId: process.env.S3_ACCESS_KEY || 'minioadmin',
    secretAccessKey: process.env.S3_SECRET_KEY || 'minioadmin',
    bucket: process.env.S3_BUCKET || 'internview-recordings',
    forcePathStyle: process.env.S3_FORCE_PATH_STYLE === 'true',
  },

  // ── Recording ──────────────────────────────────────
  recording: {
    outputDir: process.env.RECORDING_OUTPUT_DIR || '/tmp/internview-recordings',
    format: 'webm', // VP8/Opus stream copy uyumlu
  },
};

module.exports = config;
