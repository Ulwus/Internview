import { spawn } from 'node:child_process';
import { createReadStream, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { randomUUID } from 'node:crypto';

import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { Kafka } from 'kafkajs';

const sessionId = process.env.SMOKE_SESSION_ID || randomUUID();
const bucket = process.env.S3_BUCKET || 'internview-recordings';
const s3Endpoint = process.env.S3_ENDPOINT || 'http://localhost:9000';
const s3AccessKey = process.env.S3_ACCESS_KEY || 'minioadmin';
const s3SecretKey = process.env.S3_SECRET_KEY || 'minioadmin';
const kafkaBrokers = (process.env.KAFKA_BOOTSTRAP_SERVERS || 'localhost:29092').split(',');
const topic = process.env.RECORDING_SEGMENTS_TOPIC || 'recording-segments';
const segmentSeconds = Number(process.env.RECORDING_SEGMENT_SECONDS || 10);
const segmentCount = Number(process.env.SMOKE_SEGMENT_COUNT || 3);

const phrases = [
  'Hello, this is the candidate speaking about backend experience and teamwork.',
  'At this moment the interviewer asks a question about system design and Kafka.',
  'The candidate answers with details about recording segments and speech analysis.',
  'The interviewer closes the conversation and thanks the candidate for joining.',
];

const workDir = path.join(tmpdir(), `internview-smoke-${sessionId}`);
mkdirSync(workDir, { recursive: true });

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stderr = '';
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${command} ${args.join(' ')} failed (${code}): ${stderr}`));
    });
    child.on('error', reject);
  });
}

function padSecond(second) {
  return String(second).padStart(6, '0');
}

async function generateSegment(index) {
  const aiffPath = path.join(workDir, `${index}.aiff`);
  const webmPath = path.join(workDir, `${index}.webm`);
  const phrase = phrases[index % phrases.length];

  await run('say', ['-o', aiffPath, phrase]);
  await run('ffmpeg', [
    '-y',
    '-f', 'lavfi',
    '-i', `color=c=black:s=640x360:r=15:d=${segmentSeconds}`,
    '-i', aiffPath,
    '-filter_complex', `[1:a]apad,atrim=0:${segmentSeconds}[a]`,
    '-map', '0:v',
    '-map', '[a]',
    '-c:v', 'libvpx',
    '-c:a', 'libopus',
    '-t', String(segmentSeconds),
    webmPath,
  ]);
  return webmPath;
}

async function main() {
  const s3 = new S3Client({
    endpoint: s3Endpoint,
    region: 'us-east-1',
    credentials: {
      accessKeyId: s3AccessKey,
      secretAccessKey: s3SecretKey,
    },
    forcePathStyle: true,
  });
  const kafka = new Kafka({ clientId: 'internview-smoke', brokers: kafkaBrokers });
  const producer = kafka.producer();
  await producer.connect();

  for (let index = 0; index < segmentCount; index += 1) {
    const startSecond = index * segmentSeconds;
    const endSecond = startSecond + segmentSeconds;
    const key = `recordings/${sessionId}/${padSecond(startSecond)}-${padSecond(endSecond)}.webm`;
    const webmPath = await generateSegment(index);

    await s3.send(new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: createReadStream(webmPath),
      ContentType: 'video/webm',
    }));

    const timestamp = new Date().toISOString();
    const payload = {
      session_id: sessionId,
      segment_index: index,
      start_second: startSecond,
      end_second: endSecond,
      duration_seconds: segmentSeconds,
      recorded_video_url: `${s3Endpoint}/${bucket}/${key}`,
      s3_key: key,
    };
    await producer.send({
      topic,
      messages: [{
        key: sessionId,
        value: JSON.stringify({
          event_type: 'RECORDING_SEGMENT_UPLOADED',
          event_id: `evt-${randomUUID()}`,
          timestamp,
          payload,
        }),
      }],
    });
    console.log(`uploaded_and_published ${key}`);
  }

  await producer.disconnect();
  rmSync(workDir, { recursive: true, force: true });
  console.log(`SMOKE_SESSION_ID=${sessionId}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
