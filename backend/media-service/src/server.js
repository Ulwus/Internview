'use strict';

const express = require('express');
const cors = require('cors');
const config = require('./config');
const logger = require('./logger');
const mediasoupManager = require('./mediasoup-manager');
const apiRoutes = require('./api');

async function main() {
  // ── Mediasoup Worker'ları başlat ────────────────────
  await mediasoupManager.init();

  // ── Express App ────────────────────────────────────
  const app = express();

  app.use(cors());
  app.use(express.json());

  // Request loglama
  app.use((req, _res, next) => {
    logger.debug(`${req.method} ${req.url}`);
    next();
  });

  // Health check
  app.get('/health', (_req, res) => {
    res.json({
      status: 'UP',
      service: 'media-service',
      workers: mediasoupManager.workers.length,
      rooms: mediasoupManager.routers.size,
    });
  });

  // API routes
  app.use(apiRoutes);

  // Error handler
  app.use((err, _req, res, _next) => {
    logger.error('İstek hatası', { error: err.message, stack: err.stack });
    res.status(500).json({ error: err.message });
  });

  // ── Sunucuyu başlat ────────────────────────────────
  const port = config.server.port;
  app.listen(port, () => {
    logger.info(`Media Service başlatıldı: http://0.0.0.0:${port}`);
    logger.info(`Worker sayısı: ${mediasoupManager.workers.length}`);
  });

  // ── Graceful shutdown ──────────────────────────────
  const shutdown = async (signal) => {
    logger.info(`${signal} alındı, kapatılıyor...`);
    await mediasoupManager.shutdown();
    process.exit(0);
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

main().catch((err) => {
  logger.error('Media Service başlatılamadı', { error: err.message, stack: err.stack });
  process.exit(1);
});
