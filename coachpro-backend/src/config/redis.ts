import Redis from 'ioredis';
import dotenv from 'dotenv';
dotenv.config();

const getRedisUrl = () => {
  if (process.env.REDIS_URL) return process.env.REDIS_URL;
  return `redis://:${process.env.REDIS_PASS || ''}@${process.env.REDIS_HOST || 'localhost'}:${process.env.REDIS_PORT || 6379}`;
};

export const redis = new Redis(getRedisUrl(), {
  maxRetriesPerRequest: null,
});

redis.on('connect', () => {
  console.log('✅ Connected to Redis successfully');
});

redis.on('error', (err) => {
  console.error('❌ Redis Connection Error:', err);
});
