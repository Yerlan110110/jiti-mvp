const { getDb } = require('../config/database');

// In-memory location store (replaces Redis for MVP)
const driverLocations = new Map();

class LocationService {
  updateDriverLocation(driverId, lat, lng) {
    driverLocations.set(driverId, {
      lat,
      lng,
      updatedAt: Date.now(),
    });

    // Also update in DB for persistence
    const db = getDb();
    db.prepare("UPDATE users SET latitude = ?, longitude = ?, updated_at = datetime('now') WHERE id = ?")
      .run(lat, lng, driverId);
  }

  getDriverLocation(driverId) {
    return driverLocations.get(driverId) || null;
  }

  getAllOnlineDriverLocations() {
    const result = [];
    for (const [driverId, loc] of driverLocations) {
      // Only include recent updates (last 60 seconds)
      if (Date.now() - loc.updatedAt < 60000) {
        result.push({ driverId, ...loc });
      }
    }
    return result;
  }

  setDriverOnline(driverId, online) {
    const db = getDb();
    db.prepare("UPDATE users SET is_online = ?, updated_at = datetime('now') WHERE id = ?")
      .run(online ? 1 : 0, driverId);

    if (!online) {
      driverLocations.delete(driverId);
    }
  }

  removeDriver(driverId) {
    driverLocations.delete(driverId);
  }
}

module.exports = new LocationService();
