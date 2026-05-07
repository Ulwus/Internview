'use strict';

const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3');
const { Upload } = require('@aws-sdk/lib-storage');
const fs = require('fs');
const path = require('path');
const config = require('./config');
const logger = require('./logger');

/**
 * AWS S3 (MinIO uyumlu) dosya yükleme servisi.
 *
 * Multipart upload ile büyük dosyaları verimli şekilde yükler.
 */
class S3Uploader {
  constructor() {
    this.client = new S3Client({
      endpoint: config.s3.endpoint,
      region: config.s3.region,
      credentials: {
        accessKeyId: config.s3.accessKeyId,
        secretAccessKey: config.s3.secretAccessKey,
      },
      forcePathStyle: config.s3.forcePathStyle,
    });
  }

  /**
   * Dosyayı S3'e yükler.
   * @param {string} filePath Yerel dosya yolu
   * @param {string} s3Key S3 object key (örn: recordings/roomId/timestamp.webm)
   * @returns {Promise<string>} Yüklenen dosyanın S3 URL'si
   */
  async upload(filePath, s3Key) {
    const fileStream = fs.createReadStream(filePath);
    const fileName = path.basename(filePath);

    logger.info(`S3 upload başlıyor: ${fileName} → s3://${config.s3.bucket}/${s3Key}`);

    const upload = new Upload({
      client: this.client,
      params: {
        Bucket: config.s3.bucket,
        Key: s3Key,
        Body: fileStream,
        ContentType: this._getContentType(filePath),
      },
      queueSize: 4,
      partSize: 5 * 1024 * 1024, // 5 MB
      leavePartsOnError: false,
    });

    upload.on('httpUploadProgress', (progress) => {
      logger.debug(`S3 upload ilerleme: ${s3Key}`, {
        loaded: progress.loaded,
        total: progress.total,
      });
    });

    const result = await upload.done();
    const url = `${config.s3.endpoint}/${config.s3.bucket}/${s3Key}`;
    logger.info(`S3 upload tamamlandı: ${url}`);

    return url;
  }

  /**
   * Buffer'ı S3'e yükler.
   * @param {Buffer} buffer
   * @param {string} s3Key
   * @param {string} contentType
   * @returns {Promise<string>}
   */
  async uploadBuffer(buffer, s3Key, contentType) {
    logger.info(`S3 upload (buffer) başlıyor: s3://${config.s3.bucket}/${s3Key}`);

    const upload = new Upload({
      client: this.client,
      params: {
        Bucket: config.s3.bucket,
        Key: s3Key,
        Body: buffer,
        ContentType: contentType || 'application/octet-stream',
      },
      queueSize: 2,
      partSize: 5 * 1024 * 1024,
      leavePartsOnError: false,
    });

    const result = await upload.done();
    const url = `${config.s3.endpoint}/${config.s3.bucket}/${s3Key}`;
    logger.info(`S3 upload (buffer) tamamlandı: ${url}`);
    return url;
  }

  async getObject(s3Key) {
    const cmd = new GetObjectCommand({
      Bucket: config.s3.bucket,
      Key: s3Key,
    });
    return await this.client.send(cmd);
  }

  /**
   * Dosya uzantısından Content-Type belirler.
   * @param {string} filePath
   * @returns {string}
   */
  _getContentType(filePath) {
    const ext = path.extname(filePath).toLowerCase();
    const types = {
      '.webm': 'video/webm',
      '.mp4': 'video/mp4',
      '.mkv': 'video/x-matroska',
      '.ogg': 'audio/ogg',
    };
    return types[ext] || 'application/octet-stream';
  }
}

const s3Uploader = new S3Uploader();
module.exports = s3Uploader;
