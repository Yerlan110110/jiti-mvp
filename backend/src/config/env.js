require('dotenv').config();
const crypto = require('crypto');

const env = {
  port: process.env.PORT || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  isProduction: process.env.NODE_ENV === 'production',

  // JWT — generate strong random secret if not provided
  jwtSecret: process.env.JWT_SECRET && process.env.JWT_SECRET !== 'CHANGE_ME_TO_RANDOM_64_CHAR_STRING'
    ? process.env.JWT_SECRET
    : (() => {
        const generated = crypto.randomBytes(64).toString('hex');
        console.warn('⚠️  JWT_SECRET не задан! Сгенерирован временный ключ. Задайте JWT_SECRET в .env для production.');
        return generated;
      })(),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',

  // SMS
  smsMock: process.env.SMS_MOCK === 'true',
  smsMockCode: process.env.SMS_MOCK_CODE || '1234',

  // Database
  databaseUrl: process.env.DATABASE_URL || null,

  // CORS
  corsOrigins: process.env.CORS_ORIGINS
    ? process.env.CORS_ORIGINS.split(',').map(s => s.trim())
    : ['http://localhost:3000'],

  // Admin phone
  adminPhone: process.env.ADMIN_PHONE || null,
};

module.exports = env;
