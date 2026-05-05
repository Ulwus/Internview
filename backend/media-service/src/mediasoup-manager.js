'use strict';

const mediasoup = require('mediasoup');
const config = require('./config');
const logger = require('./logger');

/**
 * Mediasoup Worker pool ve Room (Router) yönetimi.
 *
 * Her room bir Router'a karşılık gelir.
 * Worker'lar round-robin ile dağıtılır.
 */
class MediasoupManager {
  constructor() {
    /** @type {mediasoup.types.Worker[]} */
    this.workers = [];
    this.nextWorkerIndex = 0;

    /** @type {Map<string, mediasoup.types.Router>} roomId → Router */
    this.routers = new Map();
  }

  /**
   * Yapılandırılmış sayıda Mediasoup Worker başlatır.
   */
  async init() {
    const numWorkers = config.mediasoup.numWorkers;
    logger.info(`Mediasoup Worker başlatılıyor: ${numWorkers} adet`);

    for (let i = 0; i < numWorkers; i++) {
      const worker = await mediasoup.createWorker({
        logLevel: config.mediasoup.worker.logLevel,
        logTags: config.mediasoup.worker.logTags,
        rtcMinPort: config.mediasoup.worker.rtcMinPort,
        rtcMaxPort: config.mediasoup.worker.rtcMaxPort,
      });

      worker.on('died', (error) => {
        logger.error(`Mediasoup Worker #${i} öldü`, { error: error?.message });
        // Production'da process restart gerekir
        setTimeout(() => process.exit(1), 2000);
      });

      this.workers.push(worker);
      logger.info(`Mediasoup Worker #${i} başlatıldı (pid=${worker.pid})`);
    }
  }

  /**
   * Round-robin ile sonraki Worker'ı seçer.
   * @returns {mediasoup.types.Worker}
   */
  getNextWorker() {
    const worker = this.workers[this.nextWorkerIndex];
    this.nextWorkerIndex = (this.nextWorkerIndex + 1) % this.workers.length;
    return worker;
  }

  /**
   * Yeni bir room (Router) oluşturur.
   * @param {string} roomId
   * @returns {Promise<mediasoup.types.Router>}
   */
  async createRoom(roomId) {
    if (this.routers.has(roomId)) {
      logger.warn(`Room zaten mevcut: ${roomId}`);
      return this.routers.get(roomId);
    }

    const worker = this.getNextWorker();
    const router = await worker.createRouter({
      mediaCodecs: config.mediasoup.router.mediaCodecs,
    });

    this.routers.set(roomId, router);
    logger.info(`Room oluşturuldu: ${roomId} (worker pid=${worker.pid})`);

    router.on('workerclose', () => {
      logger.warn(`Room Router kapandı (worker close): ${roomId}`);
      this.routers.delete(roomId);
    });

    return router;
  }

  /**
   * Belirtilen room'un Router'ını döndürür.
   * @param {string} roomId
   * @returns {mediasoup.types.Router|undefined}
   */
  getRouter(roomId) {
    return this.routers.get(roomId);
  }

  /**
   * Room'u kapatır ve kaynakları serbest bırakır.
   * @param {string} roomId
   */
  closeRoom(roomId) {
    const router = this.routers.get(roomId);
    if (router) {
      router.close();
      this.routers.delete(roomId);
      logger.info(`Room kapatıldı: ${roomId}`);
    }
  }

  /**
   * Tüm Worker'ları kapatır.
   */
  async shutdown() {
    for (const worker of this.workers) {
      worker.close();
    }
    this.workers = [];
    this.routers.clear();
    logger.info('Mediasoup Manager kapatıldı');
  }
}

// Singleton instance
const manager = new MediasoupManager();
module.exports = manager;
