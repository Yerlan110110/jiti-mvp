const { Router } = require('express');
const authController = require('../controllers/auth.controller');
const { authMiddleware } = require('../middleware/auth');
const { authLimiter } = require('../middleware/rateLimit');

const router = Router();

// Rate-limited auth endpoints (5 requests/min per IP)
router.post('/send-code', authLimiter, (req, res, next) => authController.sendCode(req, res, next));
router.post('/verify-code', authLimiter, (req, res, next) => authController.verifyCode(req, res, next));
router.post('/register', authMiddleware, (req, res, next) => authController.register(req, res, next));
router.get('/me', authMiddleware, (req, res, next) => authController.getMe(req, res, next));

module.exports = router;
