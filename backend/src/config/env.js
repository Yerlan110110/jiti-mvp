require('dotenv').config();
const crypto = require('crypto');

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
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',

  smsMock: process.env.SMS_MOCK === 'true',
  smsMockCode: process.env.SMS_MOCK_CODE || '1234',

  databaseUrl: process.env.DATABASE_URL || null,

  // CORS - если *, то разрешаем всем, иначе отдаем массив доменов
  corsOrigins: process.env.CORS_ORIGINS === '*' 
    ? '*' 
    : process.env.CORS_ORIGINS
      ? process.env.CORS_ORIGINS.split(',').map(s => s.trim())
      : ['http://localhost:3000'],

  adminPhone: process.env.ADMIN_PHONE || null,
};

module.exports = env;
