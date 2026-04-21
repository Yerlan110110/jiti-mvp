const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const config = require('../config/env');
const { getDb } = require('../config/database');

// Allowed roles — admin can ONLY be set via direct DB or ADMIN_PHONE
const ALLOWED_ROLES = ['client', 'driver'];

// Phone validation: must start with + and contain 10-15 digits
const PHONE_REGEX = /^\+\d{10,15}$/;

class AuthService {
  sendCode(phone) {
    if (!PHONE_REGEX.test(phone)) {
      throw Object.assign(new Error('Неверный формат телефона. Пример: +77001234567'), { status: 400 });
    }

    const db = getDb();
    const code = config.smsMock ? config.smsMockCode : String(Math.floor(1000 + Math.random() * 9000));
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
    const id = uuidv4();

    // Cleanup expired codes for this phone
    db.prepare('DELETE FROM verification_codes WHERE phone = ? AND (used = 1 OR expires_at < datetime(?))').run(phone, new Date().toISOString());

    // Limit active codes per phone (max 3)
    const activeCount = db.prepare('SELECT COUNT(*) as cnt FROM verification_codes WHERE phone = ? AND used = 0').get(phone);
    if (activeCount.cnt >= 3) {
      throw Object.assign(new Error('Слишком много запросов кода, попробуйте позже'), { status: 429 });
    }

    db.prepare(
      'INSERT INTO verification_codes (id, phone, code, expires_at) VALUES (?, ?, ?, ?)'
    ).run(id, phone, code, expiresAt);

    // Only log SMS code in development
    if (!config.isProduction) {
      console.log(`📱 SMS code for ${phone}: ${code}`);
    }

    return { success: true, message: 'Код отправлен' };
  }

  verifyCode(phone, code) {
    if (!PHONE_REGEX.test(phone)) {
      throw Object.assign(new Error('Неверный формат телефона'), { status: 400 });
    }

    if (!code || code.length !== 4) {
      throw Object.assign(new Error('Код должен быть 4 цифры'), { status: 400 });
    }

    const db = getDb();
    const record = db.prepare(
      'SELECT * FROM verification_codes WHERE phone = ? AND code = ? AND used = 0 ORDER BY created_at DESC LIMIT 1'
    ).get(phone, code);

    if (!record) {
      throw Object.assign(new Error('Неверный код'), { status: 400 });
    }

    if (new Date(record.expires_at) < new Date()) {
      db.prepare('DELETE FROM verification_codes WHERE id = ?').run(record.id);
      throw Object.assign(new Error('Код истёк'), { status: 400 });
    }

    // Mark code as used
    db.prepare('UPDATE verification_codes SET used = 1 WHERE id = ?').run(record.id);

    // Check if user exists
    let user = db.prepare('SELECT * FROM users WHERE phone = ?').get(phone);
    const isNewUser = !user;

    if (isNewUser) {
      const userId = uuidv4();
      // Auto-assign admin role if phone matches ADMIN_PHONE
      const role = config.adminPhone && phone === config.adminPhone ? 'admin' : 'client';
      db.prepare('INSERT INTO users (id, phone, role) VALUES (?, ?, ?)').run(userId, phone, role);
      user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    }

    const token = jwt.sign({ userId: user.id, role: user.role }, config.jwtSecret, {
      expiresIn: config.jwtExpiresIn,
    });

    return { token, user: this._sanitizeUser(user), isNewUser };
  }

  register(userId, data) {
    const db = getDb();
    const { name, role, carBrand, carModel, carColor, carPlate } = data;

    if (!name || !role) {
      throw Object.assign(new Error('Имя и роль обязательны'), { status: 400 });
    }

    // Sanitize name
    const sanitizedName = String(name).trim().substring(0, 100);
    if (sanitizedName.length < 2) {
      throw Object.assign(new Error('Имя слишком короткое'), { status: 400 });
    }

    // Block admin role assignment via API
    if (!ALLOWED_ROLES.includes(role)) {
      throw Object.assign(new Error('Недопустимая роль. Доступные: client, driver'), { status: 403 });
    }

    if (role === 'driver' && !carPlate) {
      throw Object.assign(new Error('Госномер обязателен для водителя'), { status: 400 });
    }

    const updates = { name: sanitizedName, role };
    if (role === 'driver') {
      Object.assign(updates, {
        car_brand: carBrand ? String(carBrand).trim().substring(0, 50) : null,
        car_model: carModel ? String(carModel).trim().substring(0, 50) : null,
        car_color: carColor ? String(carColor).trim().substring(0, 30) : null,
        car_plate: String(carPlate).trim().substring(0, 20),
      });
    }

    const setClauses = Object.keys(updates).map(k => `${k} = ?`).join(', ');
    const values = Object.values(updates);

    db.prepare(`UPDATE users SET ${setClauses}, updated_at = datetime('now') WHERE id = ?`).run(...values, userId);

    // Re-fetch user with potentially updated role
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);

    // Check if admin already had admin role — preserve it
    const tokenRole = user.role;
    const token = jwt.sign({ userId: user.id, role: tokenRole }, config.jwtSecret, {
      expiresIn: config.jwtExpiresIn,
    });

    return { token, user: this._sanitizeUser(user) };
  }

  getUser(userId) {
    const db = getDb();
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!user) throw Object.assign(new Error('Пользователь не найден'), { status: 404 });
    return this._sanitizeUser(user);
  }

  _sanitizeUser(user) {
    return {
      id: user.id,
      phone: user.phone,
      name: user.name,
      role: user.role,
      carBrand: user.car_brand,
      carModel: user.car_model,
      carColor: user.car_color,
      carPlate: user.car_plate,
      isOnline: !!user.is_online,
      createdAt: user.created_at,
    };
  }
}

module.exports = new AuthService();
