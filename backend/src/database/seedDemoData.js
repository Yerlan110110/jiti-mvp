const { v4: uuidv4 } = require('uuid');
const config = require('../config/env');
const { getDb } = require('../config/database');

const demoUsers = [
  {
    phone: '+77000001001',
    name: 'Демо клиент',
    role: 'client',
  },
  {
    phone: '+77000001002',
    name: 'Демо водитель',
    role: 'driver',
    car_brand: 'Toyota',
    car_model: 'Camry',
    car_color: 'Белый',
    car_plate: '001 JTI 10',
  },
];

async function upsertUser(user) {
  const db = getDb();
  const existing = await db.get('SELECT id FROM users WHERE phone = ?', [user.phone]);

  if (existing) {
    await db.run(`
      UPDATE users
      SET name = ?, role = ?, car_brand = ?, car_model = ?, car_color = ?, car_plate = ?,
          updated_at = datetime('now')
      WHERE phone = ?
    `, [
      user.name,
      user.role,
      user.car_brand || null,
      user.car_model || null,
      user.car_color || null,
      user.car_plate || null,
      user.phone,
    ]);
    return existing.id;
  }

  const id = uuidv4();
  await db.run(`
    INSERT INTO users (id, phone, name, role, car_brand, car_model, car_color, car_plate)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `, [
    id,
    user.phone,
    user.name,
    user.role,
    user.car_brand || null,
    user.car_model || null,
    user.car_color || null,
    user.car_plate || null,
  ]);
  return id;
}

async function seedDemoData() {
  const db = getDb();
  for (const user of demoUsers) {
    await upsertUser(user);
  }

  if (config.adminPhone) {
    const existingAdmin = await db.get('SELECT id FROM users WHERE phone = ?', [config.adminPhone]);
    if (existingAdmin) {
      await db.run(`
        UPDATE users
        SET name = COALESCE(NULLIF(name, ''), 'Администратор'), role = 'admin',
            updated_at = datetime('now')
        WHERE phone = ?
      `, [config.adminPhone]);
    } else {
      await db.run('INSERT INTO users (id, phone, name, role) VALUES (?, ?, ?, ?)', [
        uuidv4(),
        config.adminPhone,
        'Администратор',
        'admin',
      ]);
    }
  }

  console.log('✅ Demo users ready: client +77000001001, driver +77000001002, admin ' + config.adminPhone);
}

module.exports = { seedDemoData };
