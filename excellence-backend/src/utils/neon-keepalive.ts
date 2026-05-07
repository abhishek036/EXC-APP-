import { prisma } from '../config/prisma';

const KEEPALIVE_INTERVAL_MS = 4 * 60 * 1000; // 4 minutes

/**
 * Neon serverless Postgres pauses compute after ~5 minutes of inactivity.
 * The first query after a pause incurs a 500ms–2s cold-start penalty.
 *
 * This keepalive sends a lightweight `SELECT 1` every 4 minutes
 * to prevent the cold start, which is critical for real-time Socket.io events.
 */
export function startNeonKeepalive(): void {
  if (process.env.NODE_ENV !== 'production') {
    console.log('[Neon Keepalive] Skipped — not in production');
    return;
  }

  const ping = async () => {
    try {
      await prisma.$queryRaw`SELECT 1`;
    } catch (e: any) {
      console.error('[Neon Keepalive] Ping failed:', e?.message ?? e);
    }
  };

  setInterval(ping, KEEPALIVE_INTERVAL_MS);
  console.log(`[Neon Keepalive] Started — pinging every ${KEEPALIVE_INTERVAL_MS / 1000}s`);
}
