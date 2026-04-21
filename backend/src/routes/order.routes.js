const { Router } = require('express');
const orderController = require('../controllers/order.controller');
const { authMiddleware, roleMiddleware } = require('../middleware/auth');

const router = Router();

router.use(authMiddleware);

router.post('/', roleMiddleware('client'), (req, res, next) => orderController.create(req, res, next));
router.get('/available', roleMiddleware('driver'), (req, res, next) => orderController.getAvailable(req, res, next));
router.get('/my', (req, res, next) => orderController.getMyOrders(req, res, next));
router.get('/active', (req, res, next) => orderController.getActive(req, res, next));
router.get('/:id', (req, res, next) => orderController.getById(req, res, next));
router.get('/:id/responses', (req, res, next) => orderController.getResponses(req, res, next));
router.post('/:id/respond', roleMiddleware('driver'), (req, res, next) => orderController.respond(req, res, next));
router.post('/:id/select-driver', roleMiddleware('client'), (req, res, next) => orderController.selectDriver(req, res, next));
router.post('/:id/start', roleMiddleware('driver'), (req, res, next) => orderController.startTrip(req, res, next));
router.post('/:id/complete', roleMiddleware('driver'), (req, res, next) => orderController.completeTrip(req, res, next));
router.post('/:id/cancel', (req, res, next) => orderController.cancel(req, res, next));

module.exports = router;
