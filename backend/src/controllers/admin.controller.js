const { getDb } = require('../config/database');
const locationService = require('../services/location.service');
const authService = require('../services/auth.service');

class AdminController {
  async getUsers(req, res, next) {
    try {
      const db = getDb();
      const { role, search, limit = 50, offset = 0 } = req.query;
      let query = 'SELECT * FROM users WHERE 1=1';
      const params = [];

      if (role) { query += ' AND role = ?'; params.push(role); }
      if (search) { query += ' AND (name LIKE ? OR phone LIKE ?)'; params.push(`%${search}%`, `%${search}%`); }

      query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
      params.push(parseInt(limit), parseInt(offset));

      const users = await db.all(query, params);
      const total = await db.get('SELECT COUNT(*) as cnt FROM users' + (role ? ' WHERE role = ?' : ''), role ? [role] : []);

      res.json({
        users: users.map(u => authService._sanitizeUser(u)),
        total: total.cnt,
      });
    } catch (err) { next(err); }
  }

  async blockUser(req, res, next) {
    try {
      const db = getDb();
      const { blocked } = req.body;
      await db.run("UPDATE users SET is_blocked = ?, updated_at = datetime('now') WHERE id = ?", [blocked ? 1 : 0, req.params.id]);
      res.json({ success: true });
    } catch (err) { next(err); }
  }

  async getOnlineDrivers(req, res, next) {
    try {
      const locations = await locationService.getAllOnlineDriverLocations();
      const db = getDb();
      const drivers = await Promise.all(locations.map(async loc => {
        const driver = await db.get('SELECT * FROM users WHERE id = ?', [loc.driverId]);
        return driver ? { ...authService._sanitizeUser(driver), lat: loc.lat, lng: loc.lng } : null;
      }));
      res.json(drivers.filter(Boolean));
    } catch (err) { next(err); }
  }
}

module.exports = new AdminController();
