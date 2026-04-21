const config = require('./env');
const path = require('path');
const fs = require('fs');

let db;

function getDb() {
  if (!db) {
    let dbPath;
    if (config.databaseUrl) {
      console.warn('⚠️ WARNING: Using SQLite in cloud environment without persistent volume config.');
      dbPath = config.databaseUrl.replace('sqlite://', '');
      
      // Resolve path so we can ensure the directory exists
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
    db = new Database(dbPath);
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
  }
  return db;
}

module.exports = { getDb };
