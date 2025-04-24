import Foundation
import CoreLocation
import UserNotifications
import MapKit
import AWAREFramework

class LocationHandler: NSObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    static let shared = LocationHandler()
    private var notificationSent = false
    let geocoder = CLGeocoder()
    private var neighborhoods: [MKPolygon: String] = [:]
    private var currentNeighborhood: String?
    private var timer: Timer?
    private var startTime: Date?
    private var lastLocationCheckTime: Date?
    public var lastKnownLocation: CLLocationCoordinate2D?
    private var locationManager: CLLocationManager?
    private var lastNotificationTime: Date? // Track the last notification time

    override init() {
        super.init()
        setupLocationManager()
        setupNotificationActions()
        if let fileURL = Bundle.main.url(forResource: "Neighborhoods-4", withExtension: "geojson") {
            self.neighborhoods = loadNeighborhoods(from: fileURL) ?? [:]
        } else {
            print("Failed to locate the 'Neighborhoods-4.geojson' file.")
        }
        countAndPrintNeighborhoodsInFile()
        // ✅ Start event data sync timer every 10 seconds
        //startEventSyncTimer()
    }

    func countAndPrintNeighborhoodsInFile() {
        if let fileURL = Bundle.main.url(forResource: "Neighborhoods-4", withExtension: "geojson") {
            do {
                let data = try Data(contentsOf: fileURL)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                guard let featureCollection = json as? [String: Any],
                      let features = featureCollection["features"] as? [[String: Any]] else {
                    print("Unable to parse the GeoJSON file.")
                    return
                }

                var neighborhoodCounts: [String: Int] = [:]

                for feature in features {
                    if let properties = feature["properties"] as? [String: Any],
                       let neighborhoodName = properties["NAMELSAD"] as? String {
                        neighborhoodCounts[neighborhoodName, default: 0] += 1
                    }
                }

                for (neighborhoodName, count) in neighborhoodCounts {
                    print("\(neighborhoodName): \(count)")
                }
            } catch {
                print("Error reading or parsing GeoJSON file: \(error)")
            }
        } else {
            print("Failed to locate the 'Neighborhoods-4.geojson' file.")
        }
    }

    private func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            lastKnownLocation = location.coordinate
        }
    }

    /*
    ============================================================
    📌 NOTIFICATION TRACKING STRUCTURE
    ============================================================

    This system logs all notification events and interactions
    to track user engagement and ensure accurate data collection.

    🟢 EVENT TYPES:
    ------------------------------------------------------------
    | Event Type                  | Description                                  |
    |-----------------------------|----------------------------------------------|
    | notification_scheduled      | When a notification is scheduled to be sent  |
    | notification_displayed      | When a notification is shown to the user     |
    | notification_opened         | User taps on the notification                |
    | notification_dismissed      | User explicitly dismisses the notification   |
    | notification_ignored        | Notification remains unclicked for 15 mins   |

    🟢 STORED DATA FIELDS:
    ------------------------------------------------------------
    | Field Name        | Description                                           |
    |-------------------|-------------------------------------------------------|
    | timestamp        | The exact time (human-readable) when the event occurs |
    | identifier       | Unique notification ID                                |
    | notification_type | Type of notification (e.g., SURVEY, ALERT, REMINDER) |
    | title           | Title of the notification                              |
    | body            | Notification message content                           |
    | action          | User's interaction (Opened, Dismissed, Swiped, Ignored)|
    | neighborhood    | If applicable, logs the neighborhood location          |

    */

    
    
    
    func startEventSyncTimer() {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                let eventLogger = AWAREEventLogger.shared()

                // ✅ Get device ID from AWAREStudy
                let deviceID = AWAREStudy.shared().getDeviceId()

                // ✅ Generate a human-readable timestamp
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let readableTimestamp = dateFormatter.string(from: Date())

                // ✅ Create a properly formatted log message as a plain string
                let eventType = "event_data_sync"
                let eventDetails = "Sync triggered at \(readableTimestamp)"
                let logMessage = "\(eventType), \(readableTimestamp), \(eventDetails)" // Simple CSV string

                // ✅ Store log data as a flat dictionary (no JSON nesting)
                let logEntry: [String: String] = [
                    "device_id": deviceID,
                    "timestamp": readableTimestamp,  // 👈 Now storing as a human-readable timestamp
                    "log_message": logMessage  // 👈 Plain string (not JSON)
                ]

                // ✅ Log event using AWAREEventLogger
                eventLogger.logEvent(logEntry)

                // ✅ Start syncing event data
                eventLogger.startSyncDB()

                print("📡 Event Data Sync Triggered at \(readableTimestamp)")
                print("📝 Sync Event Stored: \(logMessage)")
            }
        }
    }

    
    func setupNotificationActions() {
        let openSurveyAction = UNNotificationAction(
            identifier: "OPEN_SURVEY",
            title: "Take Survey",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_SURVEY",
            title: "Dismiss",
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: "SURVEY_NOTIFICATION",
            actions: [openSurveyAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    
    
    func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager?.distanceFilter = 10
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
        UNUserNotificationCenter.current().delegate = self
    }


    private func getCurrentLocation() -> CLLocationCoordinate2D? {
        return lastKnownLocation
    }

    func startPeriodicLocationChecks() {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.checkLocationChange()
        }
    }

    private func checkLocationChange() {
        print("🔄 Running location check at \(Date())")

        // Ensure we have a valid last known location
        guard let lastCheckTime = lastLocationCheckTime, let currentLocation = getCurrentLocation() else {
            lastLocationCheckTime = Date()
            print("⚠️ No last known location available. Skipping location check.")
            return
        }

        // Check if the last update was at least 10 seconds ago
        let timeSinceLastCheck = Date().timeIntervalSince(lastCheckTime)
        print("⏳ Time since last location check: \(timeSinceLastCheck) seconds")

        if timeSinceLastCheck >= 10 {
            print("✅ Time condition met. Checking for location change...")

            if hasLocationChanged(currentLocation) {
                print("📍 Location CHANGED. Updating...")
                handleLocationUpdate(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            } else {
                print("⏳ Location UNCHANGED. Skipping update.")
            }

            lastLocationCheckTime = Date()
        } else {
            print("⏳ Not enough time has passed. Waiting until 10 seconds is reached.")
        }
    }

    private func hasLocationChanged(_ newLocation: CLLocationCoordinate2D) -> Bool {
        guard let lastLocation = lastKnownLocation else {
            return true
        }

        let distance = CLLocation(latitude: newLocation.latitude, longitude: newLocation.longitude)
                     .distance(from: CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude))

        return distance > 10 // meters, adjust this threshold as needed
    }

    func handleLocationUpdate(latitude: Double, longitude: Double) {
        let locationPoint = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        notificationSent = false
        var foundNeighborhood: String?

        for (polygon, name) in neighborhoods {
            if isPoint(locationPoint, insidePolygon: polygon) {
                print("Found point inside the neighborhood: \(name)")
                foundNeighborhood = name
                if currentNeighborhood != name {
                    stopTimer()
                    startTimer(neighborhood: name)
                }
                notificationSent = true
                break
            }
        }

        if foundNeighborhood == nil && currentNeighborhood != nil {
            stopTimer()
        }

        if !notificationSent {
            reverseGeocodeAndHandleNeighborhood(latitude: latitude, longitude: longitude)
        }
    }

    private func isPoint(_ point: CLLocationCoordinate2D, insidePolygon polygon: MKPolygon) -> Bool {
        let polygonRenderer = MKPolygonRenderer(polygon: polygon)
        let mapPoint = MKMapPoint(point)
        let polygonViewPoint = polygonRenderer.point(for: mapPoint)

        let isInside = polygonRenderer.path.contains(polygonViewPoint)
        print("Point \(point) is \(isInside ? "inside" : "outside") the polygon.")
        return isInside
    }

    private func startTimer(neighborhood: String) {
        currentNeighborhood = neighborhood
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
            guard let strongSelf = self else { return }
            let timeSpent = Int(Date().timeIntervalSince(strongSelf.startTime ?? Date()))
            print("Time spent in \(neighborhood): \(timeSpent) seconds")

            if timeSpent >= 180 { // 5 minutes = 300 seconds
                strongSelf.timer?.invalidate()
                strongSelf.timer = nil
                strongSelf.handleFiveMinutesStay(neighborhood: neighborhood)
            }
        }
    }

    // Log Notification Event (Copied from AppDelegate)
    // Log and Sync Notification Events Immediately
    //  Improved Log and Sync Function (Formatted for DB Structure)
    // Define a Set to track recently logged events (Prevent duplicates)
    private var recentLogs: Set<String> = []

    //  Improved Log and Sync Function (Formatted for DB Structure)
    func logNotificationEvent(
        event: String,
        identifier: String,
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
        let eventLogger = AWAREEventLogger.shared()
        let deviceID = AWAREStudy.shared().getDeviceId()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let readableTimestamp = dateFormatter.string(from: Date())

        let logKey = "\(event)_\(identifier)"
        if recentLogs.contains(logKey) {
            print("⚠️ Duplicate event detected, skipping log: \(logKey)")
            return
        }
        recentLogs.insert(logKey)

        let eventCategory = "location_notification"

        // ✅ Build the log entry
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

        if let lat = latitude {
            data["latitude"] = lat
        }
        if let lon = longitude {
            data["longitude"] = lon
        }

        let logEntry: [String: Any] = [
            "timestamp": readableTimestamp,
            "device_id": deviceID,
            "event_category": eventCategory,
            "data": data
        ]

        eventLogger.logEvent(logEntry)
        eventLogger.startSyncDB()

        print("📡 Logged and Synced Notification Event:")
        print("  • Category: \(eventCategory)")
        print("  • Event Type: \(event)")
        print("  • Timestamp: \(readableTimestamp)")
        print("  • Device ID: \(deviceID)")

        print("  • Data:")
        for (key, value) in data {
            print("     - \(key): \(value)")
        }

    }



    private func handleFiveMinutesStay(neighborhood: String) {
        print("⏳ User stayed 5 min in \(neighborhood). Scheduling notification.")

        let notificationContent = createNotificationContent()
        let notificationIdentifier = UUID().uuidString

        scheduleNotification(content: notificationContent, identifier: notificationIdentifier, delay: 1)

        print("🔔 Scheduled notification \(notificationIdentifier) for \(neighborhood)")

        // 📍 Try to retrieve coordinates from locationManager or fallback to lastKnownLocation
        var lat: Double?
        var lon: Double?

        if let currentLocation = locationManager?.location?.coordinate {
            lat = currentLocation.latitude
            lon = currentLocation.longitude
            print("📍 Using locationManager coordinates: \(lat!), \(lon!)")
        } else if let fallback = lastKnownLocation {
            lat = fallback.latitude
            lon = fallback.longitude
            print("📍 Using fallback coordinates from lastKnownLocation: \(lat!), \(lon!)")
        } else {
            print("⚠️ No GPS coordinates available at time of logging.")
        }

        // ✅ Log event using centralized logger
        NotificationLogger.shared.logEventOnce(
            eventCategory: "location_notification",
            event: "location_notification_scheduled",
            identifier: notificationIdentifier,
            title: "Location Notification",
            body: "User stayed 5 minutes in \(neighborhood)",
            neighborhood: neighborhood,
            notificationType: "LOCATION_SURVEY",
            latitude: lat,
            longitude: lon
        )

        // ✅ Remove notification after 15 minutes and log if ignored
        DispatchQueue.main.asyncAfter(deadline: .now() + 900) {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
            self.checkIfNotificationIgnored(notificationIdentifier)
        }
    }

    //Handle Notifications Ignored (Expired After 15 min)
    func checkIfNotificationIgnored(_ identifier: String) {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let stillDelivered = notifications.contains { $0.request.identifier == identifier }
            if stillDelivered {
                print("❗️ Notification \(identifier) was IGNORED by the user.")
                self.logNotificationEvent(
                    event: "notification_ignored",
                    identifier: identifier,
                    action: "No Interaction",
                    notificationType: "LOCATION_SURVEY"
                )
            }
        }
    }


    private func createNotificationContent() -> UNMutableNotificationContent {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "Your next Survey is ready (L)"
        notificationContent.body = "    "
        notificationContent.sound = UNNotificationSound.default
        notificationContent.categoryIdentifier = "SURVEY_NOTIFICATION"

        notificationContent.userInfo = [
            "url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk",
            "invisibleText": "Location",
            "notification_type": "LOCATION_SURVEY" // ✅ Critical for filtering in logging
        ]

        return notificationContent
    }




    func scheduleNotification(content: UNMutableNotificationContent, identifier: String, delay: TimeInterval) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled: \(identifier)")
                self.logNotificationEvent(
                    event: "notification_scheduled",
                    identifier: identifier,
                    title: content.title,
                    body: content.body,
                    notificationType: "LOCATION_SURVEY"
                )
            }
        }
    }


    // Handle Delivered Notifications (When User Receives It)
    @objc(userNotificationCenter:willPresentNotification:withCompletionHandler:)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        let identifier = notification.request.identifier
        let content = notification.request.content
        let userInfo = content.userInfo
        let notificationType = userInfo["notification_type"] as? String ?? "UNKNOWN"

        // 🛑 ONLY log location-based notifications in LocationHandler
        guard notificationType == "LOCATION_SURVEY" else {
            print("⛔️ Skipping non-location notification: \(identifier)")
            if #available(iOS 14.0, *) {
                completionHandler([.list, .banner, .sound, .badge])
            } else {
                // Fallback on earlier versions
            }
            return
        }

        NotificationLogger.shared.logEventOnce(
            eventCategory: "location_notification",
            event: "location_notification_delivered",
            identifier: identifier,
            title: content.title,
            body: content.body,
            notificationType: notificationType
        )

        if #available(iOS 14.0, *) {
            completionHandler([.list, .banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }



    // Handle User Interaction with Notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        let notification = response.notification
        let identifier = notification.request.identifier
        let title = notification.request.content.title
        let body = notification.request.content.body
        let userInfo = notification.request.content.userInfo

        let urlString = userInfo["url"] as? String ?? ""
        let notificationType = userInfo["notification_type"] as? String ?? "UNKNOWN"

        // ✅ Determine correct event category
        let eventCategory: String = {
            switch notificationType {
                case "RANDOM_SURVEY": return "random_notification"
                case "LOCATION_SURVEY": return "location_notification"
                default: return "general_notification"
            }
        }()

        // ✅ Determine action and log accordingly
        let (event, actionDescription): (String, String) = {
            switch response.actionIdentifier {
                case "OPEN_SURVEY", "OPEN_RANDOM_SURVEY", UNNotificationDefaultActionIdentifier:
                    return ("notification_opened", response.actionIdentifier == UNNotificationDefaultActionIdentifier ? "Opened Directly" : "Opened")
                case "DISMISS_SURVEY", "DISMISS_RANDOM_SURVEY", UNNotificationDismissActionIdentifier:
                    return ("notification_dismissed", response.actionIdentifier == UNNotificationDismissActionIdentifier ? "Swiped Dismiss" : "Dismissed")
                default:
                    return ("notification_unknown_interaction", response.actionIdentifier)
            }
        }()

        // ✅ Log the event
        NotificationLogger.shared.logEventOnce(
            eventCategory: eventCategory,
            event: event,
            identifier: identifier,
            title: title,
            body: body,
            url: urlString,
            action: actionDescription,
            notificationType: notificationType
        )

        // ✅ Open URL if tapped
        if event == "notification_opened", let url = URL(string: urlString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }

        completionHandler()
    }



    private func openSurveyURL(from response: UNNotificationResponse) {
        if let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
    }

    private func logNotificationInteraction(id: String, action: String) {
        let timestamp = Date()
        print("📊 Notification \(id): Action - \(action) at \(timestamp)")
        // Here, store this interaction in your analytics, local DB, or send it remotely
    }
    
    private func scheduleReminderNotification() {
        let reminderContent = createNotificationContent()
        reminderContent.title = "Reminder:"
        let reminderIdentifier = UUID().uuidString

        scheduleNotification(content: reminderContent, identifier: reminderIdentifier, delay: 1)

        print("🔄 Reminder notification \(reminderIdentifier) scheduled.")

        // Track ignored reminders similarly
        DispatchQueue.main.asyncAfter(deadline: .now() + 900) {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reminderIdentifier])
            self.checkIfNotificationIgnored(reminderIdentifier)
        }
    }

    
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        if let startTime = startTime, let neighborhood = currentNeighborhood {
            let timeSpent = Int(Date().timeIntervalSince(startTime))
            let notificationText = "Total time spent in \(neighborhood): \(timeSpent) seconds"
            print(notificationText)
        }
        startTime = nil
        currentNeighborhood = nil
    }

    private func reverseGeocodeAndHandleNeighborhood(latitude: Double, longitude: Double) {
        let location = CLLocation(latitude: latitude, longitude: longitude)

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error in reverse geocoding: \(error)")
                return
            }
            
            if let placemark = placemarks?.first, let neighborhood = placemark.subLocality {
                if self.currentNeighborhood != neighborhood && self.canSendNotification() {
                    self.lastNotificationTime = Date()
                    self.currentNeighborhood = neighborhood
                }
            } else {
                print("Neighborhood not found.")
            }
        }
    }

    private func canSendNotification() -> Bool {
        guard let lastNotificationTime = lastNotificationTime else {
            return true
        }
        return Date().timeIntervalSince(lastNotificationTime) > 3600 // 1 hour
    }

    private func loadNeighborhoods(from fileURL: URL) -> [MKPolygon: String]? {
        do {
            let data = try Data(contentsOf: fileURL)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            
            guard let featureCollection = json as? [String: Any],
                  let features = featureCollection["features"] as? [[String: Any]] else {
                return nil
            }
            
            var neighborhoods = [MKPolygon: String]()
            
            for feature in features {
                if let properties = feature["properties"] as? [String: Any],
                  let neighborhoodName = properties["NAMELSAD"] as? String,
                  let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String,
                  type == "MultiPolygon",
                  let coordinatesArray = geometry["coordinates"] as? [[[[Double]]]] {
                    let polygon = coordinatesArray[0][0].map {
                        CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
                    }
                    let mkPolygon = MKPolygon(coordinates: polygon, count: polygon.count)
                    neighborhoods[mkPolygon] = neighborhoodName
                }
            }
            return neighborhoods
        } catch {
            print("Error reading or parsing GeoJSON file: \(error)")
            return nil
        }
    }

    private func pointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        let x = point.longitude
        let y = point.latitude
        var isInside = false
        var i = 0
        var j = polygon.count - 1

        while i < polygon.count {
            let xi = polygon[i].longitude, yi = polygon[i].latitude
            let xj = polygon[j].longitude, yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
            if intersect {
                isInside = !isInside
            }
            j = i
            i += 1
        }
        return isInside
    }

    private func coordinates(for polygon: MKPolygon) -> [CLLocationCoordinate2D] {
        let points = polygon.points()
        let pointCount = polygon.pointCount

        var coordinates = [CLLocationCoordinate2D]()
        for i in 0..<pointCount {
            let mapPoint = points[i]
            let coordinate = mapPoint.coordinate
            coordinates.append(coordinate)
        }
        return coordinates
    }
}

func initializeAWAREFrameworkComponents() {
    let locationHandler = LocationHandler.shared // ✅ Use the singleton instance!
    let core = AWARECore.shared()
    let study = AWAREStudy.shared()
    let manager = AWARESensorManager.shared()

    core.requestPermissionForPushNotification { (notifState, error) in
        core.requestPermissionForBackgroundSensing { (locState) in
            let fusedLocation = FusedLocations(awareStudy: study)
            manager.add(fusedLocation)
            fusedLocation.setSensorEventHandler { (sensor, data) in
                if let longitude = data?["double_longitude"] as? Double,
                   let latitude = data?["double_latitude"] as? Double {
                    locationHandler.handleLocationUpdate(latitude: latitude, longitude: longitude)
                }
            }
            fusedLocation.saveAll = true
            fusedLocation.startSensor()
        }
    }
    AWAREStatusMonitor.shared().activate(withCheckInterval: 10)
}

