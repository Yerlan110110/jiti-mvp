const { getDb, getDbKind } = require('../config/database');
const { seedDemoData } = require('./seedDemoData');

async function migrate() {
  const db = getDb();
  const isPostgres = getDbKind() === 'postgres';

  await db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      phone TEXT UNIQUE NOT NULL,
      name TEXT,
      role TEXT NOT NULL DEFAULT 'client',
      car_brand TEXT,
      car_model TEXT,
      car_color TEXT,
      car_plate TEXT,
      is_online INTEGER DEFAULT 0,
      is_blocked INTEGER DEFAULT 0,
      latitude REAL,
      longitude REAL,
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS orders (
      id TEXT PRIMARY KEY,
      client_id TEXT NOT NULL REFERENCES users(id),
      driver_id TEXT REFERENCES users(id),
      pickup_address TEXT,
      dropoff_address TEXT,
      comment TEXT,
      pickup_lat REAL NOT NULL,
      pickup_lng REAL NOT NULL,
      dropoff_lat REAL NOT NULL,
      dropoff_lng REAL NOT NULL,
      client_price REAL NOT NULL,
      final_price REAL,
      status TEXT DEFAULT 'created',
      created_at TEXT DEFAULT (datetime('now')),
      updated_at TEXT DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS order_responses (
      id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL REFERENCES orders(id),
      driver_id TEXT NOT NULL REFERENCES users(id),
      proposed_price REAL NOT NULL,
      status TEXT DEFAULT 'pending',
      created_at TEXT DEFAULT (datetime('now')),
      UNIQUE(order_id, driver_id)
    );

    CREATE TABLE IF NOT EXISTS verification_codes (
      id TEXT PRIMARY KEY,
      phone TEXT NOT NULL,
      code TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      used INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_orders_client ON orders(client_id);
    CREATE INDEX IF NOT EXISTS idx_orders_driver ON orders(driver_id);
    CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
    CREATE INDEX IF NOT EXISTS idx_responses_order ON order_responses(order_id);
    CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
    CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
  `);

  if (isPostgres) {
    await db.exec(`
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_address TEXT;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS dropoff_address TEXT;
      ALTER TABLE orders ADD COLUMN IF NOT EXISTS comment TEXT;
    `);
  } else {
    const orderColumns = (await db.all('PRAGMA table_info(orders)')).map(col => col.name);
    if (!orderColumns.includes('pickup_address')) {
      await db.exec('ALTER TABLE orders ADD COLUMN pickup_address TEXT');
    }
    if (!orderColumns.includes('dropoff_address')) {
      await db.exec('ALTER TABLE orders ADD COLUMN dropoff_address TEXT');
    }
    if (!orderColumns.includes('comment')) {
      await db.exec('ALTER TABLE orders ADD COLUMN comment TEXT');
    }
  }

  console.log('✅ Database migrated successfully');
  await seedDemoData();
}

// Run directly
if (require.main === module) {
  migrate()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = { migrate };
