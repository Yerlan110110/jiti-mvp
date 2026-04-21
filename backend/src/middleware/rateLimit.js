/**
 * In-memory rate limiter (no Redis dependency for MVP).
 * Tracks request counts per IP within a sliding window.
 */

const rateLimitStore = new Map();

// Cleanup old entries every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of rateLimitStore) {
    if (now - entry.resetTime > 0) {
      rateLimitStore.delete(key);
    }
  }
}, 5 * 60 * 1000);

function rateLimit({ windowMs = 60 * 1000, max = 60, message = 'Слишком много запросов, попробуйте позже' } = {}) {
  return (req, res, next) => {
    const key = req.ip + ':' + req.path;
    const now = Date.now();
    let entry = rateLimitStore.get(key);

    if (!entry || now > entry.resetTime) {
      entry = { count: 0, resetTime: now + windowMs };
      rateLimitStore.set(key, entry);
    }

    entry.count++;

    res.setHeader('X-RateLimit-Limit', max);
    res.setHeader('X-RateLimit-Remaining', Math.max(0, max - entry.count));
    res.setHeader('X-RateLimit-Reset', Math.ceil(entry.resetTime / 1000));

    if (entry.count > max) {
      return res.status(429).json({ error: message });
    }

    next();
  };
}

// Pre-configured limiters
const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  message: 'Слишком много попыток, подождите минуту',
});

const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
});

module.exports = { rateLimit, authLimiter, apiLimiter };
