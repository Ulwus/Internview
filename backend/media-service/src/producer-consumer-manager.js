'use strict';

const logger = require('./logger');
const mediasoupManager = require('./mediasoup-manager');
const transportManager = require('./transport-manager');

/**
 * Producer / Consumer yaşam döngüsü yönetimi.
 *
 * Producer: Client medya akışını sunucuya gönderir.
 * Consumer: Sunucu medya akışını diğer client'a yönlendirir.
 */
class ProducerConsumerManager {
  constructor() {
    /** @type {Map<string, mediasoup.types.Producer>} producerId → Producer */
    this.producers = new Map();

    /** @type {Map<string, mediasoup.types.Consumer>} consumerId → Consumer */
    this.consumers = new Map();
  }

  /**
   * Yeni bir Producer oluşturur (client → SFU).
   * @param {string} transportId
   * @param {string} kind 'audio' | 'video'
   * @param {object} rtpParameters
   * @returns {Promise<object>} Producer bilgileri
   */
  async produce(transportId, kind, rtpParameters) {
    const transport = transportManager.getTransport(transportId);
    if (!transport) {
      throw new Error(`Transport bulunamadı: ${transportId}`);
    }

    const producer = await transport.produce({ kind, rtpParameters });

    this.producers.set(producer.id, producer);

    producer.on('transportclose', () => {
      logger.info(`Producer transport kapandı: ${producer.id}`);
      this.producers.delete(producer.id);
    });

    producer.on('@close', () => {
      this.producers.delete(producer.id);
    });

    logger.info(`Producer oluşturuldu: ${producer.id} (kind=${kind})`);

    return {
      id: producer.id,
      kind: producer.kind,
      rtpParameters: producer.rtpParameters,
    };
  }

  /**
   * Yeni bir Consumer oluşturur (SFU → client).
   * @param {string} roomId
   * @param {string} transportId Consumer transport'u
   * @param {string} producerId Consume edilecek Producer
   * @param {object} rtpCapabilities Client'ın RTP capabilities
   * @returns {Promise<object>} Consumer bilgileri
   */
  async consume(roomId, transportId, producerId, rtpCapabilities) {
    const router = mediasoupManager.getRouter(roomId);
    if (!router) {
      throw new Error(`Room bulunamadı: ${roomId}`);
    }

    // Router'ın bu producer'ı tüketip tüketemeyeceğini kontrol et
    if (!router.canConsume({ producerId, rtpCapabilities })) {
      throw new Error(`Router consume yapamaz: producerId=${producerId}`);
    }

    const transport = transportManager.getTransport(transportId);
    if (!transport) {
      throw new Error(`Transport bulunamadı: ${transportId}`);
    }

    const consumer = await transport.consume({
      producerId,
      rtpCapabilities,
      paused: true, // Client resume edene kadar bekle
    });

    this.consumers.set(consumer.id, consumer);

    consumer.on('transportclose', () => {
      logger.info(`Consumer transport kapandı: ${consumer.id}`);
      this.consumers.delete(consumer.id);
    });

    consumer.on('producerclose', () => {
      logger.info(`Consumer producer kapandı: ${consumer.id}`);
      this.consumers.delete(consumer.id);
    });

    consumer.on('@close', () => {
      this.consumers.delete(consumer.id);
    });

    logger.info(`Consumer oluşturuldu: ${consumer.id} (producer=${producerId})`);

    return {
      id: consumer.id,
      producerId: consumer.producerId,
      kind: consumer.kind,
      rtpParameters: consumer.rtpParameters,
    };
  }

  /**
   * Consumer'ı resume eder (paused → active).
   * @param {string} consumerId
   */
  async resumeConsumer(consumerId) {
    const consumer = this.consumers.get(consumerId);
    if (!consumer) {
      throw new Error(`Consumer bulunamadı: ${consumerId}`);
    }
    await consumer.resume();
    logger.info(`Consumer resume edildi: ${consumerId}`);
  }

  /**
   * Producer'ı döndürür.
   * @param {string} producerId
   * @returns {mediasoup.types.Producer|undefined}
   */
  getProducer(producerId) {
    return this.producers.get(producerId);
  }

  /**
   * Consumer'ı döndürür.
   * @param {string} consumerId
   * @returns {mediasoup.types.Consumer|undefined}
   */
  getConsumer(consumerId) {
    return this.consumers.get(consumerId);
  }
}

const producerConsumerManager = new ProducerConsumerManager();
module.exports = producerConsumerManager;
