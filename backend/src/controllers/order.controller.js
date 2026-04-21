const orderService = require('../services/order.service');

class OrderController {
  async create(req, res, next) {
    try {
      const order = orderService.createOrder(req.user.id, req.body);
      const io = req.app.get('io');
      if (io) io.to('drivers:online').emit('order:new', order);
      res.status(201).json(order);
    } catch (err) { next(err); }
  }

  async getAvailable(req, res, next) {
    try {
      const orders = orderService.getAvailableOrders();
      res.json(orders);
    } catch (err) { next(err); }
  }

  async getById(req, res, next) {
    try {
      // Pass requester ID for access control
      const order = orderService.getOrder(req.params.id, req.user.id);
      res.json(order);
    } catch (err) { next(err); }
  }

  async getMyOrders(req, res, next) {
    try {
      const orders = req.user.role === 'driver'
        ? orderService.getDriverOrders(req.user.id)
        : orderService.getClientOrders(req.user.id);
      res.json(orders);
    } catch (err) { next(err); }
  }

  async getActive(req, res, next) {
    try {
      const order = orderService.getActiveOrder(req.user.id, req.user.role);
      res.json(order);
    } catch (err) { next(err); }
  }

  async respond(req, res, next) {
    try {
      const { proposedPrice } = req.body;
      if (!proposedPrice) return res.status(400).json({ error: 'Укажите цену' });
      const response = orderService.respondToOrder(req.params.id, req.user.id, proposedPrice);
      const io = req.app.get('io');
      if (io) io.to(`order:${req.params.id}`).emit('order:response', response);
      res.status(201).json(response);
    } catch (err) { next(err); }
  }

  async getResponses(req, res, next) {
    try {
      // Pass requester ID for access control
      const responses = orderService.getOrderResponses(req.params.id, req.user.id);
      res.json(responses);
    } catch (err) { next(err); }
  }

  async selectDriver(req, res, next) {
    try {
      const { responseId } = req.body;
      if (!responseId) return res.status(400).json({ error: 'Укажите ID отклика' });
      const order = orderService.selectDriver(req.params.id, req.user.id, responseId);
      const io = req.app.get('io');
      if (io) {
        io.to(`order:${req.params.id}`).emit('order:driver-selected', order);
        io.to('drivers:online').emit('order:status-changed', { orderId: order.id, status: order.status });
      }
      res.json(order);
    } catch (err) { next(err); }
  }

  async startTrip(req, res, next) {
    try {
      const order = orderService.startTrip(req.params.id, req.user.id);
      const io = req.app.get('io');
      if (io) io.to(`order:${req.params.id}`).emit('order:status-changed', order);
      res.json(order);
    } catch (err) { next(err); }
  }

  async completeTrip(req, res, next) {
    try {
      const order = orderService.completeTrip(req.params.id, req.user.id);
      const io = req.app.get('io');
      if (io) io.to(`order:${req.params.id}`).emit('order:status-changed', order);
      res.json(order);
    } catch (err) { next(err); }
  }

  async cancel(req, res, next) {
    try {
      const order = orderService.cancelOrder(req.params.id, req.user.id);
      const io = req.app.get('io');
      if (io) io.to(`order:${req.params.id}`).emit('order:status-changed', order);
      res.json(order);
    } catch (err) { next(err); }
  }

  // Admin
  async getAll(req, res, next) {
    try {
      const { status, limit, offset } = req.query;
      const result = orderService.getAllOrders(status, parseInt(limit) || 50, parseInt(offset) || 0);
      res.json(result);
    } catch (err) { next(err); }
  }

  async getStats(req, res, next) {
    try {
      const stats = orderService.getStats();
      res.json(stats);
    } catch (err) { next(err); }
  }
}

module.exports = new OrderController();
