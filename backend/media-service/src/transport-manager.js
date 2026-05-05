'use strict';

const config = require('./config');
const logger = require('./logger');
const mediasoupManager = require('./mediasoup-manager');

/**
 * WebRtcTransport ve PlainTransport yönetimi.
 *
 * Transport'lar ID bazlı map'te tutulur.
 * Client bağlantıları için WebRtcTransport,
 * Recording pipeline için PlainTransport kullanılır.
 */
class TransportManager {
  constructor() {
    /** @type {Map<string, mediasoup.types.Transport>} transportId → Transport */
    this.transports = new Map();
  }

  /**
   * Client bağlantısı için WebRtcTransport oluşturur.
   * @param {string} roomId
   * @returns {Promise<object>} Transport parametreleri (client'a gönderilecek)
   */
  async createWebRtcTransport(roomId) {
    const router = mediasoupManager.getRouter(roomId);
    if (!router) {
      throw new Error(`Room bulunamadı: ${roomId}`);
    }

    const transport = await router.createWebRtcTransport({
      listenIps: config.mediasoup.webRtcTransport.listenIps,
      enableUdp: true,
      enableTcp: true,
      preferUdp: true,
      initialAvailableOutgoingBitrate:
        config.mediasoup.webRtcTransport.initialAvailableOutgoingBitrate,
    });

    // Bant genişliği sınırı
    if (config.mediasoup.webRtcTransport.maxIncomingBitrate) {
      try {
        await transport.setMaxIncomingBitrate(
          config.mediasoup.webRtcTransport.maxIncomingBitrate
        );
      } catch (err) {
        logger.warn('maxIncomingBitrate ayarlanamadı', { error: err.message });
      }
    }

    this.transports.set(transport.id, transport);

    transport.on('dtlsstatechange', (dtlsState) => {
      if (dtlsState === 'closed') {
        logger.info(`WebRtcTransport DTLS kapandı: ${transport.id}`);
        transport.close();
        this.transports.delete(transport.id);
      }
    });

    transport.on('@close', () => {
      this.transports.delete(transport.id);
    });

    logger.info(`WebRtcTransport oluşturuldu: ${transport.id} (room=${roomId})`);

    return {
      id: transport.id,
      iceParameters: transport.iceParameters,
      iceCandidates: transport.iceCandidates,
      dtlsParameters: transport.dtlsParameters,
    };
  }

  /**
   * WebRtcTransport'u bağlar (DTLS handshake).
   * @param {string} transportId
   * @param {object} dtlsParameters
   */
  async connectTransport(transportId, dtlsParameters) {
    const transport = this.transports.get(transportId);
    if (!transport) {
      throw new Error(`Transport bulunamadı: ${transportId}`);
    }

    await transport.connect({ dtlsParameters });
    logger.info(`Transport bağlandı: ${transportId}`);
  }

  /**
   * Recording pipeline için PlainTransport oluşturur.
   * FFmpeg RTP akışını bu transport üzerinden alır.
   * @param {string} roomId
   * @returns {Promise<object>} PlainTransport bilgileri
   */
  async createPlainTransport(roomId) {
    const router = mediasoupManager.getRouter(roomId);
    if (!router) {
      throw new Error(`Room bulunamadı: ${roomId}`);
    }

    const transport = await router.createPlainTransport({
      listenIp: config.mediasoup.plainTransport.listenIp,
      rtcpMux: config.mediasoup.plainTransport.rtcpMux,
      comedia: config.mediasoup.plainTransport.comedia,
    });

    this.transports.set(transport.id, transport);

    transport.on('@close', () => {
      this.transports.delete(transport.id);
    });

    logger.info(`PlainTransport oluşturuldu: ${transport.id} (room=${roomId})`);

    return {
      id: transport.id,
      ip: transport.tuple.localIp,
      port: transport.tuple.localPort,
      rtcpPort: transport.rtcpTuple ? transport.rtcpTuple.localPort : null,
    };
  }

  /**
   * Belirtilen transport'u döndürür.
   * @param {string} transportId
   * @returns {mediasoup.types.Transport|undefined}
   */
  getTransport(transportId) {
    return this.transports.get(transportId);
  }

  /**
   * Transport'u kapatır.
   * @param {string} transportId
   */
  closeTransport(transportId) {
    const transport = this.transports.get(transportId);
    if (transport) {
      transport.close();
      this.transports.delete(transportId);
      logger.info(`Transport kapatıldı: ${transportId}`);
    }
  }
}

const transportManager = new TransportManager();
module.exports = transportManager;
