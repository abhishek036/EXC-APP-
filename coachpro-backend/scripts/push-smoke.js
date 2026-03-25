/* eslint-disable no-console */
const axios = require('axios');
const { PrismaClient } = require('@prisma/client');

const baseUrl = (process.env.SMOKE_BASE_URL || 'http://localhost:3000/api').replace(/\/$/, '');
const rootUrl = baseUrl.replace(/\/api$/, '');
const phone = process.env.SMOKE_PHONE;
const password = process.env.SMOKE_PASSWORD;
const fcmToken = process.env.SMOKE_FCM_TOKEN || `smoke-token-${Date.now()}-abcdefghijklmnop`;
const platform = process.env.SMOKE_PLATFORM || 'android';

const firebaseEnvPresent = Boolean(
  process.env.FIREBASE_SERVICE_ACCOUNT_JSON ||
    (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_CLIENT_EMAIL && process.env.FIREBASE_PRIVATE_KEY)
);

async function checkHealth() {
  const url = `${rootUrl}/health`;
  const { data } = await axios.get(url, { timeout: 8000 });
  return data;
}

function extractData(payload) {
  if (!payload || typeof payload !== 'object') return null;
  return payload.data ?? payload;
}

async function login(client) {
  if (!phone || !password) {
    throw new Error('Missing SMOKE_PHONE or SMOKE_PASSWORD');
  }

  const { data } = await client.post('/auth/login', {
    phone,
    password,
  });

  const body = extractData(data) || {};
  const accessToken = body.accessToken || body.access_token || body.token;
  const user = body.user || {};

  if (!accessToken) {
    throw new Error('Login succeeded but no access token found in response');
  }

  return { accessToken, user };
}

async function registerToken(client) {
  await client.post('/notifications/register-token', {
    token: fcmToken,
    platform,
  });
}

async function sendTestNotification(client, userId) {
  const payload = {
    title: 'Push Smoke Test',
    body: 'If you see this, push path is alive.',
    type: 'system',
    user_id: userId,
    meta: {
      route: '/teacher/notifications',
      source: 'push-smoke-script',
      dedupe_key: `smoke-${Date.now()}`,
    },
  };

  const { data } = await client.post('/notifications/send', payload);
  return extractData(data) || {};
}

async function fetchNotifications(client) {
  const { data } = await client.get('/notifications', {
    params: { page: 1, perPage: 5, read_status: 'all' },
  });
  const body = extractData(data);
  return Array.isArray(body) ? body : [];
}

async function fetchLatestDeliveryLog(userId) {
  if (!process.env.DATABASE_URL) return null;

  const prisma = new PrismaClient();
  try {
    await prisma.$connect();

    const latestLog = await prisma.notificationDeliveryLog.findFirst({
      where: {
        user_id: userId,
      },
      orderBy: {
        created_at: 'desc',
      },
      select: {
        status: true,
        error_message: true,
        token: true,
        created_at: true,
      },
    });

    return latestLog;
  } finally {
    await prisma.$disconnect();
  }
}

async function run() {
  console.log('--- CoachPro Push Smoke Test ---');
  console.log(`Base URL: ${baseUrl}`);
  console.log(`Firebase env: ${firebaseEnvPresent ? 'SET' : 'MISSING'}`);

  const health = await checkHealth();
  console.log('Health check: OK');

  const client = axios.create({
    baseURL: baseUrl,
    timeout: 15000,
    validateStatus: (s) => s >= 200 && s < 300,
  });

  const { accessToken, user } = await login(client);
  console.log(`Login: OK (role=${user.role || 'unknown'}, userId=${user.id || 'unknown'})`);

  client.defaults.headers.common.Authorization = `Bearer ${accessToken}`;

  await registerToken(client);
  console.log(`Register token: OK (${platform})`);

  if (user.role !== 'admin') {
    console.log('Send step skipped: logged user is not admin (required by /notifications/send)');
    return;
  }

  const sendResult = await sendTestNotification(client, user.id);
  console.log(`Send notification: OK delivered=${sendResult.delivered ?? 'n/a'} failed=${sendResult.failed ?? 'n/a'}`);

  const notifications = await fetchNotifications(client);
  const latest = notifications[0];
  console.log(`List notifications: OK count=${notifications.length}`);
  if (latest) {
    console.log(`Latest notification: ${latest.title || 'Untitled'} | type=${latest.type || 'n/a'}`);
  }

  const latestDelivery = await fetchLatestDeliveryLog(user.id);
  if (latestDelivery) {
    console.log(`Latest delivery log: status=${latestDelivery.status}${latestDelivery.error_message ? ` | error=${latestDelivery.error_message}` : ''}`);
  } else {
    console.log('Latest delivery log: skipped (DATABASE_URL not available to script)');
  }

  if (!firebaseEnvPresent) {
    console.log('NOTE: Firebase Admin env missing, delivery is expected to fail even if notification records are created.');
  }

  console.log('--- Smoke test completed ---');
}

run().catch((error) => {
  const status = error?.response?.status;
  const payload = error?.response?.data;
  if (status) {
    console.error(`Smoke test failed with HTTP ${status}`);
    if (payload) console.error(JSON.stringify(payload, null, 2));
  } else {
    console.error('Smoke test failed:', error.message || error);
  }
  process.exit(1);
});
