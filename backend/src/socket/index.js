const jwt = require('jsonwebtoken');
const config = require('../config/env');
const locationService = require('../services/location.service');
const { getDb } = require('../config/database');

function setupSocket(io) {
  // Auth middleware for socket connections
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) return next(new Error('Authentication required'));

    try {
      const decoded = jwt.verify(token, config.jwtSecret);
      const db = getDb();
      const user = db.prepare('SELECT * FROM users WHERE id = ?').get(decoded.userId);
      if (!user) return next(new Error('User not found'));
      socket.user = user;
      next();
    } catch (err) {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    const user = socket.user;
    console.log(`🔌 ${user.role} connected: ${user.name || user.phone} (${user.id})`);

    // Join user-specific room
    socket.join(`user:${user.id}`);

    // If client has active order, join order room
    if (user.role === 'client') {
      const db = getDb();
      const activeOrder = db.prepare(
        "SELECT id FROM orders WHERE client_id = ? AND status IN ('searching','has_responses','driver_selected','in_progress') LIMIT 1"
      ).get(user.id);
      if (activeOrder) {
        socket.join(`order:${activeOrder.id}`);
      }
    }

    // Driver: go online
    socket.on('driver:online', () => {
      if (user.role !== 'driver') return;
      locationService.setDriverOnline(user.id, true);
      socket.join('drivers:online');
      console.log(`🟢 Driver online: ${user.name || user.phone}`);
    });

    // Driver: go offline
    socket.on('driver:offline', () => {
      if (user.role !== 'driver') return;
      locationService.setDriverOnline(user.id, false);
      socket.leave('drivers:online');
      console.log(`🔴 Driver offline: ${user.name || user.phone}`);
    });

    // Driver: update location
    socket.on('driver:location-update', (data) => {
      if (user.role !== 'driver') return;
      const { lat, lng } = data;
      if (lat == null || lng == null) return;

      locationService.updateDriverLocation(user.id, lat, lng);

      // If driver has active order, broadcast to client
      const db = getDb();
      const activeOrder = db.prepare(
        "SELECT id, client_id FROM orders WHERE driver_id = ? AND status IN ('driver_selected','in_progress') LIMIT 1"
      ).get(user.id);

      if (activeOrder) {
        io.to(`order:${activeOrder.id}`).emit('driver:location', {
          driverId: user.id,
          lat,
          lng,
          timestamp: Date.now(),
        });
      }
    });

    // Client: join order room
    socket.on('order:join', (data) => {
      const { orderId } = data;
      if (orderId) {
        socket.join(`order:${orderId}`);
        console.log(`📦 ${user.role} joined order room: ${orderId}`);
      }
    });

    // Client: leave order room
    socket.on('order:leave', (data) => {
      const { orderId } = data;
      if (orderId) {
        socket.leave(`order:${orderId}`);
      }
    });

    // Request location of a user
    socket.on('location:request', (data) => {
      const { userId } = data;
      const loc = locationService.getDriverLocation(userId);
      if (loc) {
        socket.emit('location:response', { userId, ...loc });
      }
    });

    // Disconnect
    socket.on('disconnect', () => {
      if (user.role === 'driver') {
        locationService.setDriverOnline(user.id, false);
        socket.leave('drivers:online');
      }
      console.log(`❌ ${user.role} disconnected: ${user.name || user.phone}`);
    });
  });

  return io;
}

module.exports = { setupSocket };
