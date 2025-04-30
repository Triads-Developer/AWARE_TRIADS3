# 📦 CHANGELOG

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v1.0.1] – 2025-04-29

### 🚀 Added
- **Geofence-based notification delivery**: Introduced logic to send notifications only after a user remains in a defined neighborhood for 5 minutes.
- **Notification expiration logic**: Added automatic expiration and removal of notifications 90 seconds after delivery if no user interaction occurs.
- **Unified event logging system**: Created `NotificationLogger.swift` to standardize the logging of all notification interactions (delivered, opened, missed, expired).
- **GeoJSON-based location handling**: Integrated `Neighborhoods-4.geojson` for defining neighborhood boundaries used in geofencing logic.

### 🛠 Changed
- Refactored `AppDelegate.swift` and `LocationHandler.swift` to support randomized survey scheduling and location-based triggers using the updated logger.
- Updated local SQLite schema compatibility for tracking notification status and expiration timestamps.

### 🐞 Fixed
- Resolved an issue where notifications could be logged multiple times if the app restarted or if expiration logic failed.
- Fixed inconsistent behavior in tap vs. dismiss event tracking.

---

## [v1.0.0] – 2025-04-15

### ✨ Initial Release

- Forked from AWARE iOS Framework v1.14.12.
- Enabled passive mobile sensing (location, activity, phone usage).
- Implemented basic random notification delivery every 2 hours (4× daily).
- Integrated with AWARE server for sensor data upload and logging.
