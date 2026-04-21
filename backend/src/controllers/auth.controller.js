const authService = require('../services/auth.service');

class AuthController {
  async sendCode(req, res, next) {
    try {
      const { phone } = req.body;
      if (!phone) return res.status(400).json({ error: 'Укажите номер телефона' });
      const result = authService.sendCode(phone);
      res.json(result);
    } catch (err) { next(err); }
  }

  async verifyCode(req, res, next) {
    try {
      const { phone, code } = req.body;
      if (!phone || !code) return res.status(400).json({ error: 'Укажите телефон и код' });
      const result = authService.verifyCode(phone, code);
      res.json(result);
    } catch (err) { next(err); }
  }

  async register(req, res, next) {
    try {
      const result = authService.register(req.user.id, req.body);
      res.json(result);
    } catch (err) { next(err); }
  }

  async getMe(req, res, next) {
    try {
      const user = authService.getUser(req.user.id);
      res.json(user);
    } catch (err) { next(err); }
  }
}

module.exports = new AuthController();
