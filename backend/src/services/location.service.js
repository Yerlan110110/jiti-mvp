const { getDb } = require('../config/database');

// In-memory location store (replaces Redis for MVP)
const driverLocations = new Map();

class LocationService {
  async updateDriverLocation(driverId, lat, lng) {
    driverLocations.set(driverId, {
      lat,
      lng,
      updatedAt: Date.now(),
    });

    // Also update in DB for persistence
    const db = getDb();
    await db.run("UPDATE users SET latitude = ?, longitude = ?, updated_at = datetime('now') WHERE id = ?", [lat, lng, driverId]);
  }

  getDriverLocation(driverId) {
    return driverLocations.get(driverId) || null;
  }

  async getAllOnlineDriverLocations() {
    const db = getDb();
    const onlineDrivers = await db.all(`
      SELECT id, latitude, longitude
      FROM users
      WHERE role = 'driver'
        AND is_online = 1
        AND latitude IS NOT NULL
        AND longitude IS NOT NULL
    `);

    const locationsByDriver = new Map();
    for (const driver of onlineDrivers) {
      locationsByDriver.set(driver.id, {
        driverId: driver.id,
        lat: driver.latitude,
        lng: driver.longitude,
        updatedAt: null,
      });
    }

    for (const [driverId, loc] of driverLocations) {
      // Only include recent updates (last 60 seconds)
      if (Date.now() - loc.updatedAt < 60000) {
        locationsByDriver.set(driverId, { driverId, ...loc });
      }
    }

    return Array.from(locationsByDriver.values());
  }

  async setDriverOnline(driverId, online) {
    const db = getDb();
    const defaultLat = 52.1908;
    const defaultLng = 61.2006;
    await db.run(`
      UPDATE users
      SET is_online = ?,
          latitude = CASE WHEN ? = 1 THEN COALESCE(latitude, ?) ELSE latitude END,
          longitude = CASE WHEN ? = 1 THEN COALESCE(longitude, ?) ELSE longitude END,
          updated_at = datetime('now')
      WHERE id = ?
    `, [online ? 1 : 0, online ? 1 : 0, defaultLat, online ? 1 : 0, defaultLng, driverId]);

    if (!online) {
      driverLocations.delete(driverId);
    } else if (!driverLocations.has(driverId)) {
      const driver = await db.get('SELECT latitude, longitude FROM users WHERE id = ?', [driverId]);
      driverLocations.set(driverId, {
        lat: driver?.latitude || defaultLat,
        lng: driver?.longitude || defaultLng,
        updatedAt: Date.now(),
      });
    }
  }

  removeDriver(driverId) {
    driverLocations.delete(driverId);
  }
}

module.exports = new LocationService();
