const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../config/database');

// Valid status transitions
const STATUS_FLOW = {
  created: ['searching', 'cancelled'],
  searching: ['has_responses', 'cancelled'],
  has_responses: ['has_responses', 'driver_selected', 'cancelled'],
  driver_selected: ['in_progress', 'cancelled'],
  in_progress: ['completed'],
  completed: [],
  cancelled: [],
};

class OrderService {
  createOrder(clientId, data) {
    const db = getDb();
    const { pickupLat, pickupLng, dropoffLat, dropoffLng, clientPrice } = data;

    if (!pickupLat || !pickupLng || !dropoffLat || !dropoffLng || !clientPrice) {
      throw Object.assign(new Error('Все поля обязательны'), { status: 400 });
    }

    // Validate numeric values
    const lat1 = Number(pickupLat), lng1 = Number(pickupLng);
    const lat2 = Number(dropoffLat), lng2 = Number(dropoffLng);
    const price = Number(clientPrice);

    if ([lat1, lng1, lat2, lng2, price].some(v => isNaN(v))) {
      throw Object.assign(new Error('Координаты и цена должны быть числами'), { status: 400 });
    }

    if (price <= 0 || price > 1000000) {
      throw Object.assign(new Error('Некорректная цена'), { status: 400 });
    }

    const id = uuidv4();
    db.prepare(`
      INSERT INTO orders (id, client_id, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, client_price, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'searching')
    `).run(id, clientId, lat1, lng1, lat2, lng2, price);

    return this.getOrder(id);
  }

  getOrder(orderId, requesterId) {
    const db = getDb();
    const order = db.prepare(`
      SELECT o.*, 
        uc.name as client_name, uc.phone as client_phone,
        ud.name as driver_name, ud.phone as driver_phone,
        ud.car_brand, ud.car_model, ud.car_color, ud.car_plate
      FROM orders o
      LEFT JOIN users uc ON o.client_id = uc.id
      LEFT JOIN users ud ON o.driver_id = ud.id
      WHERE o.id = ?
    `).get(orderId);

    if (!order) throw Object.assign(new Error('Заказ не найден'), { status: 404 });

    // Access control: only participants or admin can view
    if (requesterId) {
      const requester = db.prepare('SELECT role FROM users WHERE id = ?').get(requesterId);
      const isParticipant = order.client_id === requesterId || order.driver_id === requesterId;
      const isAdmin = requester && requester.role === 'admin';
      if (!isParticipant && !isAdmin) {
        throw Object.assign(new Error('Нет доступа к этому заказу'), { status: 403 });
      }
    }

    return this._formatOrder(order);
  }

  getAvailableOrders() {
    const db = getDb();
    const orders = db.prepare(`
      SELECT o.*, uc.name as client_name, uc.phone as client_phone
      FROM orders o
      LEFT JOIN users uc ON o.client_id = uc.id
      WHERE o.status IN ('searching', 'has_responses')
      ORDER BY o.created_at DESC
    `).all();

    return orders.map(o => this._formatOrder(o));
  }

  getClientOrders(clientId) {
    const db = getDb();
    const orders = db.prepare(`
      SELECT o.*,
        ud.name as driver_name, ud.phone as driver_phone,
        ud.car_brand, ud.car_model, ud.car_color, ud.car_plate
      FROM orders o
      LEFT JOIN users ud ON o.driver_id = ud.id
      WHERE o.client_id = ?
      ORDER BY o.created_at DESC
    `).all(clientId);

    return orders.map(o => this._formatOrder(o));
  }

  getDriverOrders(driverId) {
    const db = getDb();
    const orders = db.prepare(`
      SELECT o.*, uc.name as client_name, uc.phone as client_phone
      FROM orders o
      LEFT JOIN users uc ON o.client_id = uc.id
      WHERE o.driver_id = ?
      ORDER BY o.created_at DESC
    `).all(driverId);

    return orders.map(o => this._formatOrder(o));
  }

  getActiveOrder(userId, role) {
    const db = getDb();
    // Fixed: no template literal in SQL — use separate prepared statements
    let order;
    if (role === 'driver') {
      order = db.prepare(`
        SELECT o.*,
          uc.name as client_name, uc.phone as client_phone,
          ud.name as driver_name, ud.phone as driver_phone,
          ud.car_brand, ud.car_model, ud.car_color, ud.car_plate
        FROM orders o
        LEFT JOIN users uc ON o.client_id = uc.id
        LEFT JOIN users ud ON o.driver_id = ud.id
        WHERE o.driver_id = ? AND o.status IN ('searching', 'has_responses', 'driver_selected', 'in_progress')
        ORDER BY o.created_at DESC LIMIT 1
      `).get(userId);
    } else {
      order = db.prepare(`
        SELECT o.*,
          uc.name as client_name, uc.phone as client_phone,
          ud.name as driver_name, ud.phone as driver_phone,
          ud.car_brand, ud.car_model, ud.car_color, ud.car_plate
        FROM orders o
        LEFT JOIN users uc ON o.client_id = uc.id
        LEFT JOIN users ud ON o.driver_id = ud.id
        WHERE o.client_id = ? AND o.status IN ('searching', 'has_responses', 'driver_selected', 'in_progress')
        ORDER BY o.created_at DESC LIMIT 1
      `).get(userId);
    }

    return order ? this._formatOrder(order) : null;
  }

  respondToOrder(orderId, driverId, proposedPrice) {
    const db = getDb();
    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(orderId);

    if (!order) throw Object.assign(new Error('Заказ не найден'), { status: 404 });
    if (!['searching', 'has_responses'].includes(order.status)) {
      throw Object.assign(new Error('Нельзя откликнуться на этот заказ'), { status: 400 });
    }

    // Validate price
    const price = Number(proposedPrice);
    if (isNaN(price) || price <= 0 || price > 1000000) {
      throw Object.assign(new Error('Некорректная цена'), { status: 400 });
    }

    const existing = db.prepare(
      'SELECT * FROM order_responses WHERE order_id = ? AND driver_id = ?'
    ).get(orderId, driverId);

    if (existing) {
      throw Object.assign(new Error('Вы уже откликнулись'), { status: 400 });
    }

    const id = uuidv4();
    db.prepare(
      'INSERT INTO order_responses (id, order_id, driver_id, proposed_price) VALUES (?, ?, ?, ?)'
    ).run(id, orderId, driverId, price);

    // Update order status
    if (order.status === 'searching') {
      db.prepare("UPDATE orders SET status = 'has_responses', updated_at = datetime('now') WHERE id = ?")
        .run(orderId);
    }

    const driver = db.prepare('SELECT * FROM users WHERE id = ?').get(driverId);
    return {
      id,
      orderId,
      driverId,
      driverName: driver.name,
      driverPhone: driver.phone,
      carBrand: driver.car_brand,
      carModel: driver.car_model,
      carColor: driver.car_color,
      carPlate: driver.car_plate,
      proposedPrice: price,
      status: 'pending',
    };
  }

  getOrderResponses(orderId, requesterId) {
    const db = getDb();

    // Access control: only order owner or responding drivers can see responses
    if (requesterId) {
      const order = db.prepare('SELECT client_id FROM orders WHERE id = ?').get(orderId);
      const requester = db.prepare('SELECT role FROM users WHERE id = ?').get(requesterId);
      const isOwner = order && order.client_id === requesterId;
      const isRespondingDriver = db.prepare('SELECT 1 FROM order_responses WHERE order_id = ? AND driver_id = ?').get(orderId, requesterId);
      const isAdmin = requester && requester.role === 'admin';
      if (!isOwner && !isRespondingDriver && !isAdmin) {
        throw Object.assign(new Error('Нет доступа к откликам'), { status: 403 });
      }
    }

    const responses = db.prepare(`
      SELECT r.*, u.name as driver_name, u.phone as driver_phone,
        u.car_brand, u.car_model, u.car_color, u.car_plate
      FROM order_responses r
      JOIN users u ON r.driver_id = u.id
      WHERE r.order_id = ?
      ORDER BY r.created_at DESC
    `).all(orderId);

    return responses.map(r => ({
      id: r.id,
      orderId: r.order_id,
      driverId: r.driver_id,
      driverName: r.driver_name,
      driverPhone: r.driver_phone,
      carBrand: r.car_brand,
      carModel: r.car_model,
      carColor: r.car_color,
      carPlate: r.car_plate,
      proposedPrice: r.proposed_price,
      status: r.status,
      createdAt: r.created_at,
    }));
  }

  selectDriver(orderId, clientId, responseId) {
    const db = getDb();
    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(orderId);

    if (!order) throw Object.assign(new Error('Заказ не найден'), { status: 404 });
    if (order.client_id !== clientId) {
      throw Object.assign(new Error('Это не ваш заказ'), { status: 403 });
    }
    if (!['has_responses', 'searching'].includes(order.status)) {
      throw Object.assign(new Error('Невозможно выбрать водителя'), { status: 400 });
    }

    const response = db.prepare('SELECT * FROM order_responses WHERE id = ? AND order_id = ?')
      .get(responseId, orderId);

    if (!response) throw Object.assign(new Error('Отклик не найден'), { status: 404 });

    // Accept this response, reject others
    db.prepare("UPDATE order_responses SET status = 'accepted' WHERE id = ?").run(responseId);
    db.prepare("UPDATE order_responses SET status = 'rejected' WHERE order_id = ? AND id != ?")
      .run(orderId, responseId);

    // Update order
    db.prepare(`
      UPDATE orders SET driver_id = ?, final_price = ?, status = 'driver_selected', updated_at = datetime('now')
      WHERE id = ?
    `).run(response.driver_id, response.proposed_price, orderId);

    return this.getOrder(orderId);
  }

  startTrip(orderId, driverId) {
    return this._updateStatus(orderId, driverId, 'driver', 'in_progress');
  }

  completeTrip(orderId, driverId) {
    return this._updateStatus(orderId, driverId, 'driver', 'completed');
  }

  cancelOrder(orderId, userId) {
    const db = getDb();
    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(orderId);
    if (!order) throw Object.assign(new Error('Заказ не найден'), { status: 404 });

    if (order.client_id !== userId && order.driver_id !== userId) {
      throw Object.assign(new Error('Нет прав'), { status: 403 });
    }

    const allowed = STATUS_FLOW[order.status];
    if (!allowed || !allowed.includes('cancelled')) {
      throw Object.assign(new Error('Невозможно отменить'), { status: 400 });
    }

    db.prepare("UPDATE orders SET status = 'cancelled', updated_at = datetime('now') WHERE id = ?")
      .run(orderId);
    return this.getOrder(orderId);
  }

  // Admin methods
  getAllOrders(status, limit = 50, offset = 0) {
    const db = getDb();

    // Sanitize limit/offset
    const safeLimit = Math.min(Math.max(1, Number(limit) || 50), 200);
    const safeOffset = Math.max(0, Number(offset) || 0);

    let query = `
      SELECT o.*,
        uc.name as client_name, uc.phone as client_phone,
        ud.name as driver_name, ud.phone as driver_phone
      FROM orders o
      LEFT JOIN users uc ON o.client_id = uc.id
      LEFT JOIN users ud ON o.driver_id = ud.id
    `;
    const params = [];

    if (status) {
      query += ' WHERE o.status = ?';
      params.push(status);
    }
    query += ' ORDER BY o.created_at DESC LIMIT ? OFFSET ?';
    params.push(safeLimit, safeOffset);

    const orders = db.prepare(query).all(...params);
    const total = db.prepare(
      status ? 'SELECT COUNT(*) as cnt FROM orders WHERE status = ?' : 'SELECT COUNT(*) as cnt FROM orders'
    ).get(...(status ? [status] : []));

    return { orders: orders.map(o => this._formatOrder(o)), total: total.cnt };
  }

  getStats() {
    const db = getDb();
    return {
      totalOrders: db.prepare('SELECT COUNT(*) as cnt FROM orders').get().cnt,
      activeOrders: db.prepare("SELECT COUNT(*) as cnt FROM orders WHERE status IN ('searching','has_responses','driver_selected','in_progress')").get().cnt,
      completedOrders: db.prepare("SELECT COUNT(*) as cnt FROM orders WHERE status = 'completed'").get().cnt,
      cancelledOrders: db.prepare("SELECT COUNT(*) as cnt FROM orders WHERE status = 'cancelled'").get().cnt,
      totalUsers: db.prepare("SELECT COUNT(*) as cnt FROM users WHERE role = 'client'").get().cnt,
      totalDrivers: db.prepare("SELECT COUNT(*) as cnt FROM users WHERE role = 'driver'").get().cnt,
      onlineDrivers: db.prepare("SELECT COUNT(*) as cnt FROM users WHERE role = 'driver' AND is_online = 1").get().cnt,
    };
  }

  _updateStatus(orderId, userId, role, newStatus) {
    const db = getDb();
    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(orderId);
    if (!order) throw Object.assign(new Error('Заказ не найден'), { status: 404 });

    // Fixed: no template literal — direct comparison
    const ownerId = role === 'driver' ? order.driver_id : order.client_id;
    if (ownerId !== userId) {
      throw Object.assign(new Error('Нет прав'), { status: 403 });
    }

    const allowed = STATUS_FLOW[order.status];
    if (!allowed || !allowed.includes(newStatus)) {
      throw Object.assign(new Error(`Невозможно сменить статус с ${order.status} на ${newStatus}`), { status: 400 });
    }

    db.prepare("UPDATE orders SET status = ?, updated_at = datetime('now') WHERE id = ?")
      .run(newStatus, orderId);
    return this.getOrder(orderId);
  }

  _formatOrder(o) {
    return {
      id: o.id,
      clientId: o.client_id,
      clientName: o.client_name || null,
      clientPhone: o.client_phone || null,
      driverId: o.driver_id || null,
      driverName: o.driver_name || null,
      driverPhone: o.driver_phone || null,
      carBrand: o.car_brand || null,
      carModel: o.car_model || null,
      carColor: o.car_color || null,
      carPlate: o.car_plate || null,
      pickupLat: o.pickup_lat,
      pickupLng: o.pickup_lng,
      dropoffLat: o.dropoff_lat,
      dropoffLng: o.dropoff_lng,
      clientPrice: o.client_price,
      finalPrice: o.final_price || null,
      status: o.status,
      createdAt: o.created_at,
      updatedAt: o.updated_at,
    };
  }
}

module.exports = new OrderService();
