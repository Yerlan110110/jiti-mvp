const { Router } = require('express');
const adminController = require('../controllers/admin.controller');
const orderController = require('../controllers/order.controller');
const { authMiddleware, roleMiddleware } = require('../middleware/auth');

const router = Router();

router.use(authMiddleware, roleMiddleware('admin'));

router.get('/users', (req, res, next) => adminController.getUsers(req, res, next));
router.post('/users/:id/block', (req, res, next) => adminController.blockUser(req, res, next));
router.get('/orders', (req, res, next) => orderController.getAll(req, res, next));
router.get('/stats', (req, res, next) => orderController.getStats(req, res, next));
router.get('/drivers/online', (req, res, next) => adminController.getOnlineDrivers(req, res, next));

module.exports = router;
