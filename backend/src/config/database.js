const config = require('./env');
const path = require('path');
const fs = require('fs');

let db;
let dbKind;

function isPostgresUrl(url) {
  return /^postgres(ql)?:\/\//i.test(url || '');
}

function toPostgresSql(sql) {
  let index = 0;
  return sql
    .replace(/datetime\('now'\)/gi, 'CURRENT_TIMESTAMP::text')
    .replace(/datetime\(\?\)/gi, '?')
    .replace(/\?/g, () => `$${++index}`);
}

function createSqliteDb() {
  let dbPath;
  if (config.databaseUrl) {
    dbPath = config.databaseUrl.replace('sqlite://', '');

    if (!path.isAbsolute(dbPath)) {
      dbPath = path.resolve(process.cwd(), dbPath);
    }
  } else {
    dbPath = path.join(__dirname, '..', '..', 'data', 'jiti.db');
  }

  const dir = path.dirname(dbPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  const Database = require('better-sqlite3');
  const sqlite = new Database(dbPath);
  sqlite.pragma('journal_mode = WAL');
  sqlite.pragma('foreign_keys = ON');
  console.log(`SQLite database: ${dbPath}`);

  return {
    kind: 'sqlite',
    async exec(sql) {
      sqlite.exec(sql);
    },
    async all(sql, params = []) {
      return sqlite.prepare(sql).all(...params);
    },
    async get(sql, params = []) {
      return sqlite.prepare(sql).get(...params);
    },
    async run(sql, params = []) {
      const result = sqlite.prepare(sql).run(...params);
      return { changes: result.changes, lastInsertRowid: result.lastInsertRowid };
    },
    async close() {
      sqlite.close();
    },
  };
}

function createPostgresDb() {
  const { Pool } = require('pg');
  const dbHost = (() => {
    try {
      return new URL(config.databaseUrl).hostname;
    } catch (_) {
      return 'unknown-host';
    }
  })();
  console.log(`Postgres database connected: ${dbHost}`);
  const pool = new Pool({
    connectionString: config.databaseUrl,
    ssl: config.databaseUrl.includes('localhost') || config.databaseUrl.includes('127.0.0.1')
      ? false
      : { rejectUnauthorized: false },
  });

  return {
    kind: 'postgres',
    async exec(sql) {
      await pool.query(toPostgresSql(sql));
    },
    async all(sql, params = []) {
      const result = await pool.query(toPostgresSql(sql), params);
      return result.rows;
    },
    async get(sql, params = []) {
      const result = await pool.query(toPostgresSql(sql), params);
      return result.rows[0];
    },
    async run(sql, params = []) {
      const result = await pool.query(toPostgresSql(sql), params);
      return { changes: result.rowCount };
    },
    async close() {
      await pool.end();
    },
  };
}

function getDb() {
  if (!db) {
    dbKind = isPostgresUrl(config.databaseUrl) ? 'postgres' : 'sqlite';
    db = dbKind === 'postgres' ? createPostgresDb() : createSqliteDb();
  }
  return db;
}

function getDbKind() {
  if (!dbKind) getDb();
  return dbKind;
}

async function closeDb() {
  if (db) {
    await db.close();
    db = null;
    dbKind = null;
  }
}

module.exports = { closeDb, getDb, getDbKind };
