const config = require('./env');

let db;

function getDb() {
  if (!db) {
    if (config.databaseUrl) {
      // In a real scenario, this would initialize PostgreSQL (e.g. using 'pg' module)
      // Since this MVP heavily uses synchronous better-sqlite3 APIs (like db.prepare().get()),
      // migrating fully to asynchronous pg driver would require rewriting ALL services.
      // 
      // TEMPORARY SOLUTION FOR HOSTING (Render): 
      // We will continue using SQLite, but save the DB in a persistent disk volume on Render.
      // We will document this in render.yaml
      console.warn('⚠️ WARNING: Using SQLite in cloud environment. Make sure you mount a persistent volume!');
      const Database = require('better-sqlite3');
      db = new Database(config.databaseUrl.replace('sqlite://', ''));
      db.pragma('journal_mode = WAL');
      db.pragma('foreign_keys = ON');
    } else {
      const Database = require('better-sqlite3');
      const path = require('path');
      const fs = require('fs');
      
      const DB_PATH = path.join(__dirname, '..', '..', 'data', 'jiti.db');
      const dir = path.dirname(DB_PATH);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      db = new Database(DB_PATH);
      db.pragma('journal_mode = WAL');
      db.pragma('foreign_keys = ON');
    }
  }
  return db;
}

module.exports = { getDb };
