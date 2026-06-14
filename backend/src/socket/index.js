const jwt = require('jsonwebtoken');
const config = require('../config/env');
const locationService = require('../services/location.service');
const { getDb } = require('../config/database');

function setupSocket(io) {
  // Auth middleware for socket connections
  io.use(async (socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) return next(new Error('Authentication required'));

    try {
      const decoded = jwt.verify(token, config.jwtSecret);
      const db = getDb();
      const user = await db.get('SELECT * FROM users WHERE id = ?', [decoded.userId]);
      if (!user) return next(new Error('User not found'));
      socket.user = user;
      next();
    } catch (err) {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', async (socket) => {
    const user = socket.user;
    console.log(`🔌 ${user.role} connected: ${user.name || user.phone} (${user.id})`);

    // Join user-specific room
    socket.join(`user:${user.id}`);

    // If client has active order, join order room
    if (user.role === 'client') {
      const db = getDb();
      const activeOrder = await db.get(
        "SELECT id FROM orders WHERE client_id = ? AND status IN ('searching','has_responses','driver_selected','in_progress') LIMIT 1"
      , [user.id]);
      if (activeOrder) {
        socket.join(`order:${activeOrder.id}`);
      }
    }

    // Driver: go online
    socket.on('driver:online', async () => {
      if (user.role !== 'driver') return;
      await locationService.setDriverOnline(user.id, true);
      socket.join('drivers:online');
      console.log(`🟢 Driver online: ${user.name || user.phone}`);
    });

    // Driver: go offline
    socket.on('driver:offline', async () => {
      if (user.role !== 'driver') return;
      await locationService.setDriverOnline(user.id, false);
      socket.leave('drivers:online');
      console.log(`🔴 Driver offline: ${user.name || user.phone}`);
    });

    // Driver: update location
    socket.on('driver:location-update', async (data) => {
      if (user.role !== 'driver') return;
      const { lat, lng } = data;
      if (lat == null || lng == null) return;

      await locationService.updateDriverLocation(user.id, lat, lng);

      // If driver has active order, broadcast to client
      const db = getDb();
      const activeOrder = await db.get(
        "SELECT id, client_id FROM orders WHERE driver_id = ? AND status IN ('driver_selected','in_progress') LIMIT 1"
      , [user.id]);

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
    socket.on('disconnect', async () => {
      if (user.role === 'driver') {
        await locationService.setDriverOnline(user.id, false);
        socket.leave('drivers:online');
      }
      console.log(`❌ ${user.role} disconnected: ${user.name || user.phone}`);
    });
  });

  return io;
}

module.exports = { setupSocket };
