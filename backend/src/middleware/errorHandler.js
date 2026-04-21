function errorHandler(err, req, res, next) {
  const status = err.status || 500;
  const isProduction = process.env.NODE_ENV === 'production';

  // Log full error server-side
  if (status >= 500) {
    console.error('❌ Server Error:', err.stack || err.message);
  } else {
    console.warn('⚠️  Client Error:', err.message);
  }

  // Never expose internal details to client in production
  const message = status >= 500 && isProduction
    ? 'Внутренняя ошибка сервера'
    : err.message || 'Внутренняя ошибка сервера';

  res.status(status).json({ error: message });
}

module.exports = { errorHandler };
