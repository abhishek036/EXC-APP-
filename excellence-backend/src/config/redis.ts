import Redis from 'ioredis';
import dotenv from 'dotenv';
dotenv.config();

const getRedisUrl = () => {
  if (process.env.REDIS_URL) return process.env.REDIS_URL;
  // No Redis URL configured — return null to skip Redis setup
  return null;
};

const redisUrl = getRedisUrl();

export const redis: Redis | null = redisUrl
  ? new Redis(redisUrl, {
      maxRetriesPerRequest: null,
      lazyConnect: true,
    })
  : null;

if (redis) {
  redis.on('connect', () => {
    console.log('✅ Connected to Redis successfully');
  });

  redis.on('error', (err) => {
    console.error('❌ Redis Connection Error:', err.message);
  });
} else {
  console.warn('⚠️ REDIS_URL not set — Redis and BullMQ will be disabled.');
}
