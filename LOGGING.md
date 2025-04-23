
# 📘 LOGGING.md – Notification & Event Logging in AWARE

This document outlines the notification and event logging framework used in the **AWARE_TRIADS3** app. The app captures user interactions with notifications, logs contextual metadata, and transmits all logs to the AWARE server for secure analysis.

Logging plays a critical role in assessing **user engagement**, **survey response rates**, and **location-aware behavior patterns**.

---

## 🧭 Overview of the Logging System

- All events are logged using a centralized class: `NotificationLogger.swift`.
- Events are sent to: `AWAREEventLogger.shared()`.
- Data format: Flat JSON dictionary.
- Data syncing: Via `startSyncDB()` on the AWARE logger.
- Location-based notifications include GPS coordinates and neighborhood names.

---

## 📂 Event Categories

| Category              | Description                                                  |
|-----------------------|--------------------------------------------------------------|
| `random_notification` | Time-based scheduled surveys (4 per day × 7 days)            |
| `location_notification` | Triggered by dwelling ≥5 mins in predefined geo-polygons |
| `general_notification` | Default for uncategorized or test notifications             |

---

## 🧾 Event Types

| Event Type                     | Description                                                         |
|--------------------------------|---------------------------------------------------------------------|
| `notification_scheduled`       | A survey notification has been scheduled (but not yet delivered)   |
| `notification_delivered`       | Notification was shown to the user                                 |
| `notification_opened`          | User tapped the notification and opened it                         |
| `notification_dismissed`       | User swiped or dismissed without engaging                          |
| `notification_ignored`         | Notification expired after 15 minutes without interaction          |
| `reminder_scheduled`           | A follow-up notification after primary expiration                  |
| `reminder_expired`             | Reminder also expired without engagement                          |
| `location_notification_scheduled` | Triggered when user stayed ≥5 min in a recognized area         |

---

## 🧱 Log Format

All logs follow the structure below:

```json
{
  "timestamp": "2025-04-16 21:03:00",
  "device_id": "3306e231-93de-42d0-8c90-36f941198f0e",
  "event_category": "random_notification",
  "data": {
    "event_type": "notification_opened",
    "identifier": "abc-123-xyz",
    "title": "Your next Survey is ready",
    "body": " ",
    "action": "Opened",
    "neighborhood": "Central West End",
    "url": "https://example.qualtrics.com/survey",
    "error": "",
    "notification_type": "RANDOM_SURVEY",
    "latitude": 38.6379,
    "longitude": -90.2628
  }
}
```

### Field Descriptions

| Field                 | Description                                               |
|----------------------|-----------------------------------------------------------|
| `timestamp`          | Human-readable time the event occurred                    |
| `device_id`          | Unique device ID assigned by AWARE                        |
| `event_category`     | Type of notification (random, location, general)          |
| `event_type`         | Event action performed (scheduled, opened, etc.)          |
| `identifier`         | Unique ID for the notification                            |
| `title`/`body`       | Text content shown in notification                        |
| `action`             | User interaction: Opened, Dismissed, Ignored              |
| `neighborhood`       | Geo-region, if location-based                             |
| `url`                | Link to survey or content                                  |
| `error`              | Optional error descriptions (e.g., scheduling issues)     |
| `notification_type`  | `RANDOM_SURVEY` or `LOCATION_SURVEY`                      |
| `latitude`/`longitude` | Coordinates when event was logged                        |

---

## 🛡 Deduplication Mechanism

To prevent multiple log entries for the same event:

- A **composite key** is generated for each event:  
  ```swift
  let logKey = "\(eventCategory)_\(event)_\(identifier)"
  ```

- Two layers of filtering:
  1. **In-memory cache (`recentlyLoggedEvents`)**: auto-expires entries older than 15 minutes.
  2. **Persistent storage (`UserDefaults`)**: retains a set of previously logged keys (`logged_notification_keys`).

This ensures **each unique event is logged once**, even across app sessions.

---

## 🧪 Example Log Sequences

### 🎯 Random Survey (User Interacts)

| Timestamp           | Event Type               | Action     | Notes                             |
|---------------------|--------------------------|------------|-----------------------------------|
| 2025-04-22 10:00:00 | notification_scheduled   | -          | Scheduled in morning block        |
| 2025-04-22 10:02:12 | notification_delivered   | -          | Appeared on lock screen           |
| 2025-04-22 10:03:00 | notification_opened      | Opened     | User tapped and opened survey     |

---

### 📍 Location-Based Notification (User Ignores)

| Timestamp           | Event Type                     | Action          | Notes                             |
|---------------------|--------------------------------|------------------|-----------------------------------|
| 2025-04-22 14:30:00 | location_notification_scheduled | -               | Triggered after 5 mins in zone    |
| 2025-04-22 14:45:00 | notification_ignored           | No Interaction  | Notification expired after 15 min |

---

### 🔁 Reminder Flow

| Timestamp           | Event Type               | Action     | Notes                             |
|---------------------|--------------------------|------------|-----------------------------------|
| 2025-04-22 12:00:00 | notification_scheduled   | -          | Initial survey scheduled          |
| 2025-04-22 12:16:00 | reminder_scheduled       | -          | Sent after original expired       |
| 2025-04-22 12:32:00 | reminder_expired         | No Interaction | No action on reminder either   |

---

## 👨‍💻 Developer Tips

- Use `NotificationLogger.shared.logEventOnce(...)` for all tracked events.
- Use `.clearLoggedKeys()` to reset deduplication logs during development/testing.
- For debugging: logs also print to Xcode console with icons like `📡`, `✅`, `❗️`.

---

## 📁 Related Files

| File                    | Purpose                                                   |
|-------------------------|-----------------------------------------------------------|
| `NotificationLogger.swift` | Core logging module for both random and geo alerts      |
| `Location_Fused2.swift`    | Tracks location changes and logs neighborhood triggers |
| `AppDelegate.swift`        | Schedules random surveys and handles system-level events |
| `Neighborhoods-4.geojson`  | GeoJSON defining neighborhood polygons for iOS mapping  |

---

## 📬 Contact

Questions, suggestions?

📧 **Reach us at:** [insert-email-here]  
🔗 **Repository:** [https://github.com/Triads-Developer/AWARE_TRIADS3](https://github.com/Triads-Developer/AWARE_TRIADS3)

---

