const store = new Map<string, { count: number; resetAt: number }>();

export interface RateLimitConfig {
  windowMs: number;
  maxRequests: number;
}

export function checkRateLimit(key: string, config: RateLimitConfig): { allowed: boolean; remaining: number } {
  const now = Date.now();
  const entry = store.get(key);
  if (!entry || entry.resetAt < now) {
    store.set(key, { count: 1, resetAt: now + config.windowMs });
    return { allowed: true, remaining: config.maxRequests - 1 };
  }
  entry.count++;
  const allowed = entry.count <= config.maxRequests;
  return { allowed, remaining: Math.max(0, config.maxRequests - entry.count) };
}

export const RATE_LIMITS = {
  auth: { windowMs: 60_000, maxRequests: 10 },
  upload: { windowMs: 60_000, maxRequests: 30 },
  api: { windowMs: 60_000, maxRequests: 120 },
};
