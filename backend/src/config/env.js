require('dotenv').config();
const crypto = require('crypto');

function cleanEnvString(value, fallback) {
  const raw = value == null ? fallback : String(value);
  let normalized = raw.trim();

  for (let i = 0; i < 3; i += 1) {
    const before = normalized;
    normalized = normalized
      .replace(/^\\+|\\+$/g, '')
      .replace(/^['"`“”]+|['"`“”]+$/g, '')
      .trim();

    try {
      const parsed = JSON.parse(normalized);
      if (typeof parsed === 'string') normalized = parsed.trim();
    } catch (_) {
      // Not JSON-wrapped, keep the cleaned value.
    }

    if (normalized === before) break;
  }

  return normalized || fallback;
}

function cleanJwtExpiresIn(value, fallback = '30d') {
  const normalized = cleanEnvString(value, fallback)
    .replace(/[\\'"`“”]/g, '')
    .trim();
  const match = normalized.match(/\b(\d+\s*(?:ms|s|m|h|d|w|y)?)\b/i);

  if (match) return match[1].replace(/\s+/g, '').toLowerCase();

  console.warn(`⚠️  JWT_EXPIRES_IN is invalid, using ${fallback}`);
  return fallback;
}

const env = {
  port: process.env.PORT || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  isProduction: process.env.NODE_ENV === 'production',

  jwtSecret: process.env.JWT_SECRET && process.env.JWT_SECRET !== 'CHANGE_ME_TO_RANDOM_64_CHAR_STRING'
    ? process.env.JWT_SECRET
    : (() => {
        const generated = crypto.randomBytes(64).toString('hex');
        console.warn('⚠️  JWT_SECRET не задан! Сгенерирован временный ключ.');
        return generated;
      })(),
  jwtExpiresIn: cleanJwtExpiresIn(process.env.JWT_EXPIRES_IN),

  smsMock: process.env.SMS_MOCK === 'true',
  smsMockCode: process.env.SMS_MOCK_CODE || '1234',

  databaseUrl: process.env.DATABASE_URL || null,

  // CORS - если *, то разрешаем всем, иначе отдаем массив доменов
  corsOrigins: process.env.CORS_ORIGINS === '*' 
    ? '*' 
    : process.env.CORS_ORIGINS
      ? process.env.CORS_ORIGINS.split(',').map(s => s.trim())
      : ['http://localhost:3000'],

  adminPhone: process.env.ADMIN_PHONE || '+77001234567',
};

module.exports = env;
