require('dotenv').config();

const express = require('express');
const http = require('http');
const cors = require('cors');
const path = require('path');
const helmet = require('helmet');
const { Server } = require('socket.io');
const config = require('./config/env');
const { migrate } = require('./database/migrate');
const { errorHandler } = require('./middleware/errorHandler');
const { apiLimiter } = require('./middleware/rateLimit');
const { setupSocket } = require('./socket/index');

// Routes
const authRoutes = require('./routes/auth.routes');
const orderRoutes = require('./routes/order.routes');
const adminRoutes = require('./routes/admin.routes');

// Initialize
const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: config.isProduction ? config.corsOrigins : '*',
    methods: ['GET', 'POST'],
  },
});

// Security middleware
app.use(helmet({
  contentSecurityPolicy: false, // Disabled for admin panel inline scripts
  crossOriginEmbedderPolicy: false,
}));

// CORS — restrict origins in production
app.use(cors({
  origin: config.isProduction ? config.corsOrigins : '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Body parser with size limit (DoS protection)
app.use(express.json({ limit: '1mb' }));

// Global rate limit for API
app.use('/api', apiLimiter);

// Make io accessible in controllers
app.set('io', io);

// Trust proxy for correct IP behind Render/Railway
app.set('trust proxy', 1);

// Simple request logger
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    if (duration > 1000 || res.statusCode >= 400) {
      console.log(`${req.method} ${req.path} → ${res.statusCode} (${duration}ms)`);
    }
  });
  next();
});

// Serve admin panel as static files
app.use('/admin', express.static(path.join(__dirname, '../../admin')));

// Routes
app.get('/api/health', (req, res) => res.json({ status: 'ok', time: new Date().toISOString() }));
app.use('/api/auth', authRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/admin', adminRoutes);

// Error handler
app.use(errorHandler);

// Setup Socket.IO
setupSocket(io);

// Run migrations and start server
migrate();

server.listen(config.port, '0.0.0.0', () => {
  console.log(`
  ╔══════════════════════════════════════╗
  ║     🚗 Jiti Backend Started 🚗      ║
  ║                                      ║
  ║   ENV:  ${config.isProduction ? 'PRODUCTION' : 'DEVELOPMENT'}               ║
  ║   REST: http://localhost:${config.port}    ║
  ║   WS:   ws://localhost:${config.port}     ║
  ║   SMS:  ${config.smsMock ? 'MOCK (code: ' + config.smsMockCode + ')' : 'LIVE'}          ║
  ╚══════════════════════════════════════╝
  `);
});

// Graceful shutdown
function shutdown(signal) {
  console.log(`\n⏹️  ${signal} received. Shutting down gracefully...`);
  server.close(() => {
    try {
      const { getDb } = require('./config/database');
      const db = getDb();
      if (db && typeof db.close === 'function') db.close();
    } catch (_) {}
    console.log('✅ Server closed.');
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 5000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
