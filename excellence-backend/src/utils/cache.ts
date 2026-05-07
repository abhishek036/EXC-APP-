import { redis } from '../config/redis';

/**
 * TTL constants — tune per use-case.
 * Shorter TTLs for data that changes often; longer for near-static config.
 */
export const TTL = {
  INSTITUTE_CONFIG: 3600,  // 1 hour   — almost never changes
  BATCH_LIST: 300,         // 5 min
  STUDENT_LIST: 120,       // 2 min
  TIMETABLE: 600,          // 10 min
  DASHBOARD_STATS: 60,     // 1 min    — frequent reads, high DB cost
  FEE_SUMMARY: 180,        // 3 min
  STUDENT_PERFORMANCE: 120, // 2 min
};

export class Cache {
  /**
   * Generates a tenant-scoped cache key.
   * Pattern: `i:<instituteId>:<resource>` or `i:<instituteId>:<resource>:<id>`
   */
  static key(instituteId: string, resource: string, id?: string): string {
    return `i:${instituteId}:${resource}${id ? `:${id}` : ''}`;
  }

  /**
   * Fetches data from Redis cache. On miss, calls `fn()`, caches the result, and returns it.
   * Gracefully degrades to direct DB call if Redis is unavailable.
   */
  static async getOrSet<T>(key: string, ttlSeconds: number, fn: () => Promise<T>): Promise<T> {
    if (!redis) return fn();

    try {
      const cached = await redis.get(key);
      if (cached) {
        return JSON.parse(cached) as T;
      }
    } catch (e: any) {
      console.warn('[Cache] GET failed, falling back to DB:', e?.message);
    }

    const fresh = await fn();

    try {
      await redis.setex(key, ttlSeconds, JSON.stringify(fresh));
    } catch (e: any) {
      console.warn('[Cache] SET failed:', e?.message);
    }

    return fresh;
  }

  /**
   * Invalidates all cache entries matching a tenant + resource pattern.
   * Call this on every mutation (create/update/delete) for the affected resource.
   */
  static async invalidate(instituteId: string, resource: string): Promise<void> {
    if (!redis) return;
    try {
      const pattern = `i:${instituteId}:${resource}*`;
      const keys = await redis.keys(pattern);
      if (keys.length > 0) {
        await redis.del(...keys);
      }
    } catch (e: any) {
      console.warn('[Cache] INVALIDATE failed:', e?.message);
    }
  }

  /**
   * Invalidates ALL cached data for an entire tenant.
   * Use sparingly — e.g., on institute settings change.
   */
  static async invalidateAll(instituteId: string): Promise<void> {
    if (!redis) return;
    try {
      const keys = await redis.keys(`i:${instituteId}:*`);
      if (keys.length > 0) {
        await redis.del(...keys);
      }
    } catch (e: any) {
      console.warn('[Cache] INVALIDATE_ALL failed:', e?.message);
    }
  }
}
