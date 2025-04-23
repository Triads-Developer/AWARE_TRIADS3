//  NotificationLogger.swift
//  aware-client-ios-v2
//
//  Created by Jessie Walker on 4/2/25.
//  Copyright © 2025 Yuuki Nishiyama. All rights reserved.

import Foundation
import AWAREFramework
import UserNotifications
import UserNotificationsUI

/// NotificationLogger is a singleton class responsible for logging all notification-related
/// events in a consistent format to the AWARE framework's event logger. It supports deduplication,
/// caching, and persistent tracking of logged notification events.
class NotificationLogger {

    /// Shared singleton instance for global access.
    static let shared = NotificationLogger()

    /// Stores unique keys of already-logged events to avoid duplication.
    private var loggedEvents: Set<String> = []

    /// Temporary in-memory store of recent events and their timestamps (for quick deduplication).
    private var recentlyLoggedEvents: [String: Date] = [:]

    /// Time interval (in seconds) to cache logged events in memory.
    private let cacheExpirationInterval: TimeInterval = 3

    /// Private initializer to enforce singleton usage and load any persisted log keys.
    private init() {
        // Retrieve any previously logged notification keys from persistent storage.
        if let saved = UserDefaults.standard.array(forKey: "logged_notification_keys") as? [String] {
            loggedEvents = Set(saved)
        }
    }

    /// Main logging method that ensures each unique event is logged only once.
    ///
    /// - Parameters:
    ///   - eventCategory: The high-level category (e.g., random_notification, location_notification).
    ///   - event: The specific type of event (e.g., scheduled, opened).
    ///   - identifier: Unique ID for the notification.
    ///   - deviceID: Unique device ID (default: from AWAREStudy).
    ///   - title, body, neighborhood, url: Optional context fields.
    ///   - errorDescription, action: Additional descriptive metadata.
    ///   - notificationType: Type label (RANDOM_SURVEY, LOCATION_SURVEY).
    ///   - latitude, longitude: GPS coordinates (if available).
    func logEventOnce(
        eventCategory: String,
        event: String,
        identifier: String,
        deviceID: String = AWAREStudy.shared().getDeviceId(),
        title: String? = nil,
        body: String? = nil,
        neighborhood: String? = nil,
        url: String? = nil,
        errorDescription: String? = nil,
        action: String? = nil,
        notificationType: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        let logKey = "\(eventCategory)_\(event)_\(identifier)"

        // Clean up memory cache before proceeding
        removeExpiredCacheEntries()

        // Prevent duplicate logs (both from memory and previously persisted keys)
        if loggedEvents.contains(logKey) || recentlyLoggedEvents.keys.contains(logKey) {
            print("⚠️ Skipping duplicate log for: \(logKey)")
            return
        }

        // Mark this logKey as used
        loggedEvents.insert(logKey)
        recentlyLoggedEvents[logKey] = Date()
        persistLoggedKey(logKey)

        // Format timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let readableTimestamp = dateFormatter.string(from: Date())

        // Prepare the main data payload
        var data: [String: Any] = [
            "event_type": event,
            "identifier": identifier,
            "action": action ?? "None",
            "title": title ?? "",
            "body": body ?? "",
            "neighborhood": neighborhood ?? "",
            "url": url ?? "",
            "error": errorDescription ?? "",
            "notification_type": notificationType ?? ""
        ]

        // Add location info if available
        if let lat = latitude { data["latitude"] = lat }
        if let lon = longitude { data["longitude"] = lon }

        // Combine everything into a single log entry
        let logEntry: [String: Any] = [
            "timestamp": readableTimestamp,
            "device_id": deviceID,
            "event_category": eventCategory,
            "data": data
        ]

        // Log to AWARE and start syncing
        let logger = AWAREEventLogger.shared()
        logger.logEvent(logEntry)
        logger.startSyncDB()

        print("📡 Logged [\(eventCategory)] \(event): \(identifier)")
        print("  • Data: \(data)")
    }

    /// Saves the log key to persistent storage to avoid duplication after restarts.
    private func persistLoggedKey(_ key: String) {
        var saved = UserDefaults.standard.array(forKey: "logged_notification_keys") as? [String] ?? []
        saved.append(key)
        UserDefaults.standard.set(saved, forKey: "logged_notification_keys")
    }

    /// Removes expired keys from in-memory cache based on expiration interval.
    private func removeExpiredCacheEntries() {
        let now = Date()
        recentlyLoggedEvents = recentlyLoggedEvents.filter { _, timestamp in
            now.timeIntervalSince(timestamp) < 15 * 60 // 15 minutes expiration
        }
    }

    /// Clears all stored log keys (both in memory and persistent storage). Useful for testing.
    func clearLoggedKeys() {
        loggedEvents.removeAll()
        recentlyLoggedEvents.removeAll()
        UserDefaults.standard.removeObject(forKey: "logged_notification_keys")
        print("🧹 Cleared all persisted and recent notification log keys.")
    }
}
