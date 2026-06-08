'use strict';

const config = require('./config');
const logger = require('./logger');

class KafkaPublisher {
  constructor() {
    this.producer = null;
    this.connecting = null;
    this.kafkaAvailable = true;
  }

  async publishRecordingSegment(segment) {
    if (!config.kafka.enabled || !this.kafkaAvailable) {
      return;
    }

    try {
      const producer = await this._getProducer();
      await producer.send({
        topic: config.kafka.recordingSegmentsTopic,
        messages: [{
          key: segment.session_id,
          value: JSON.stringify({
            event_type: 'RECORDING_SEGMENT_UPLOADED',
            event_id: segment.event_id,
            timestamp: segment.timestamp,
            payload: segment,
          }),
        }],
      });
      logger.info(`Recording segment event yayınlandı: ${segment.s3_key}`);
    } catch (err) {
      logger.warn(`Recording segment event yayınlanamadı: ${err.message}`);
    }
  }

  async _getProducer() {
    if (this.producer) {
      return this.producer;
    }
    if (this.connecting) {
      return this.connecting;
    }

    this.connecting = this._createProducer();
    this.producer = await this.connecting;
    this.connecting = null;
    return this.producer;
  }

  async _createProducer() {
    let Kafka;
    try {
      ({ Kafka } = require('kafkajs'));
    } catch (err) {
      this.kafkaAvailable = false;
      logger.warn('kafkajs dependency bulunamadı; segment event publish devre dışı.');
      throw err;
    }

    const kafka = new Kafka({
      clientId: config.kafka.clientId,
      brokers: config.kafka.brokers,
    });
    const producer = kafka.producer();
    await producer.connect();
    return producer;
  }
}

module.exports = new KafkaPublisher();
