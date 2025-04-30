# 📦 CHANGELOG

All notable changes to this project are documented in this file.

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v1.0.2] – 2025-05-01

### 🚀 Added
- Persistent expiration cleanup task to remove expired notifications post-90 seconds and log as "missed."
- Time-window constraints for push delivery (e.g., 9 AM–9 PM) to align with participant waking hours.
- Full metadata inclusion in logs (`device_id`, `title`, `notification_type`, timestamp).

### 🛠 Changed
- Refactored `AppDelegate.swift` to modularize silent push setup and local cleanup logic.
- Unified all notification tracking into `NotificationLogger.swift`.

### 🐞 Fixed
- Race condition on expired notification reentry during app restart.
- Double logging of tapped notifications resolved.

---

## [v1.0.1] – 2025-04-29

### 🚀 Added
- Geofence-based triggers using `LocationHandler.swift` and `Neighborhoods-4.geojson` (5-minute dwell logic).
- Notification expiration logic: alerts auto-dismiss and log as "missed" if no user interaction in 90 seconds.
- `NotificationLogger.swift` for unified log handling.
- Enhanced AWARE event logging for expired/tapped/missed events.

### 🛠 Changed
- `Location_Fused2.swift` split into more modular checks for location-state transitions.
- `AppDelegate.swift` updated to support restart-based recovery of active notification sessions.

### 🐞 Fixed
- Notification duplication bug on app restart.
- Missing logs for expired events due to DB lock issue.

---

## [v1.0.0] – 2025-04-15

### ✨ Initial Release
- Forked from AWARE iOS Framework v1.14.12.
- Enabled passive sensors (GPS, accelerometer, screen on/off, app use).
- Basic push notification system using local schedule (every 2 hours).
- Connected to AWARE backend for secure study data transmission.

---

## [v0.9.0] – 2025-02-28

### 🚀 Added
- Random survey notification delivery with type tagging (`R`, `S`).
- Initial GeoJSON ingestion using `Neighborhoods-4.geojson`.

---

## [v0.8.0] – 2024-06-17

### 🧪 Experimental
- Created `Location-GeoFence-Notes.md` to document planned 5-minute dwell geofence logic.
- Early prototype of region monitoring without dwell enforcement.

---

## [v0.7.0] – 2024-01-12

### 🚀 Added
- Device-based logging refinements for user state (stationary, walking).
- Initial file testing with `.gpx` and `.geojson` files.

---

## [v0.6.0] – 2023-12-11

### 🚀 Added
- Added `Speech_Detection_file.swift` and `RandomFile.swift` for experimental audio context tracking.
- Internal state logging for background vs. foreground transitions.

---

## [v0.5.0] – 2023-11-20

### 🚀 Added
- Added `Locs1.swift`, `Locs2.swift`, `SpeechFile.swift`, and `test_neighborhoods.gpx`.
- Created randomized ID logic for assigning unique participant identifiers.

---

## [v0.4.0] – 2023-11-06

### 🚀 Added
- First inclusion of multiple context modules for emotion-behavior research.
- Started upload logging validation against AWARE server.

---

## [v0.3.0] – 2023-10-30

### 🚀 Added
- Began audio stream analysis exploration.
- Uploaded baseline experimental survey prompts.

---

## [v0.2.0] – 2023-04-10

### 🛠 Setup
- Integrated AWARE core modules via CocoaPods.
- Compiled app successfully in debug mode for first on-device test.

---

## [v0.1.0] – 2023-02-15

### 🔧 Prototype
- Created project structure and initialized repository with base AWARE iOS client.

---

