//
//  AppDelegate.swift
//  aware-client-ios-v2
//
//  Created by Yuuki Nishiyama on 2019/02/27.
//  Copyright © 2019 Yuuki Nishiyama. All rights reserved.
//

import UIKit
import CoreData
import AWAREFramework
import SafariServices
import UserNotifications
import BackgroundTasks
import Foundation
import CoreLocation
import MapKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    let notificationExpirationTaskIdentifier = "Finalaware12345.notificationExpiration"
    
    var locationManager: CLLocationManager?
    var lastKnownLocation: CLLocationCoordinate2D?
    var neighborhoods: [MKPolygon: String] = [:]
    var currentNeighborhood: String?
    var timer: Timer?
    var startTime: Date?

    func getUrl() -> String {
        return "http://ec2-3-15-38-212.us-east-2.compute.amazonaws.com:8080/index.php/1/4lph4num3ric"
    }

    // Define time ranges for random notifications
    let timeRanges = [
        (startHour: 9, startMinute: 0, endHour: 11, endMinute: 0),
        (startHour: 11, startMinute: 0, endHour: 13, endMinute: 0),
        (startHour: 13, startMinute: 0, endHour: 17, endMinute: 0),
        (startHour: 17, startMinute: 0, endHour: 21, endMinute: 0)
    ]

    var hasScheduledSurveys = false

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let core = AWARECore.shared()
        let manager = AWARESensorManager.shared()
        let study = AWAREStudy.shared()
        let studyurl = getUrl()
        // Declare and initialize AWARE sensors
        let activity = IOSActivityRecognition(awareStudy: study)
        let location = Locations(awareStudy: study)
        let fuslocation = FusedLocations(awareStudy: study)
        let battery1 = Battery(awareStudy: study)
        let acc = Accelerometer(awareStudy: study)
        let blue = Bluetooth(awareStudy: study)
        let devices = DeviceUsage(awareStudy: study)
        let calls = Calls(awareStudy: study)
        
        study.setStudyURL(studyurl)
        AWAREStudy.shared().setAutoDBSyncIntervalWithMinutue(3)
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted { print("✅ Notification permissions granted.") }
        }

        setupLocationManager()
        scheduleSurveys()  // Ensure surveys are scheduled properly

        Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { _ in
            self.scheduleSurveys()
        }

        // Add AWARE sensors to the sensor manager
        manager.add(activity)
        manager.add(location)
        manager.add(fuslocation)
        manager.add(battery1)
        manager.add(acc)
        manager.add(blue)
        manager.add(calls)
        manager.add(devices)
        
        manager.addSensors(with: study)
        core.activate()

        return true
    }

    // MARK: - Location Tracking Setup
    func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager?.distanceFilter = 10
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()

        loadNeighborhoods()
        startPeriodicLocationChecks()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            lastKnownLocation = location.coordinate
            print("📍 Updated Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }


    func startPeriodicLocationChecks() {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.checkLocationChange()
        }
    }

    func checkLocationChange() {
        print("🔄 Running location check at \(Date())")

        guard let currentLocation = lastKnownLocation else {
            print("⚠️ No last known location available. Skipping location check.")
            return
        }

        handleLocationUpdate(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
    }

    func handleLocationUpdate(latitude: Double, longitude: Double) {
        let locationPoint = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        var foundNeighborhood: String?

        for (polygon, name) in neighborhoods {
            if isPoint(locationPoint, insidePolygon: polygon) {
                print("📍 Found point inside neighborhood: \(name)")
                foundNeighborhood = name
                
                if currentNeighborhood == name {
                    print("✅ Still in the same neighborhood: \(name), maintaining timer.")
                    return
                } else {
                    stopTimer()
                    startTimer(neighborhood: name)
                }
                break
            }
        }

        if foundNeighborhood == nil && currentNeighborhood != nil {
            stopTimer()
        }
    }

    func isPoint(_ point: CLLocationCoordinate2D, insidePolygon polygon: MKPolygon) -> Bool {
        let path = UIBezierPath()
        for i in 0..<polygon.pointCount {
            let mapPoint = polygon.points()[i].coordinate
            if i == 0 {
                path.move(to: CGPoint(x: mapPoint.latitude, y: mapPoint.longitude))
            } else {
                path.addLine(to: CGPoint(x: mapPoint.latitude, y: mapPoint.longitude))
            }
        }
        path.close()
        return path.contains(CGPoint(x: point.latitude, y: point.longitude))
    }


    func startTimer(neighborhood: String) {
        currentNeighborhood = neighborhood
        if startTime == nil {
            startTime = Date()
            print("⏳ Timer started for \(neighborhood). Waiting for 5 minutes.")
        }

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }
            let timeSpent = Int(Date().timeIntervalSince(strongSelf.startTime ?? Date()))
            print("⏳ Checking elapsed time in \(neighborhood): \(timeSpent) seconds")

            if timeSpent >= 180 {  // 5 minutes
                strongSelf.timer?.invalidate()
                strongSelf.timer = nil
                strongSelf.sendLocationNotification(neighborhood: neighborhood)
            }
        }
    }

    func sendLocationNotification(neighborhood: String) {
        print("🔔 Sending notification for \(neighborhood) after 5 minutes.")

        let content = UNMutableNotificationContent()
        content.title = "Your next Survey is ready (L)"
        content.body = "  "
        content.sound = .default
        content.userInfo = [
            "url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk",
            "invisibleText": "Location"
        ]
        content.categoryIdentifier = "surveyCategory"
        content.threadIdentifier = "surveyReminders"

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }

        let notificationIdentifier = UUID().uuidString
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)

        // Store event in AWAREEventLogger
        let eventDetails: [String: Any] = [
            "class": "LocationHandler",
            "event": "location_notification_scheduled",
            "identifier": notificationIdentifier,
            "title": content.title,
            "body": content.body,
            "neighborhood": neighborhood,
            "url": content.userInfo["url"] as! String,
            "timestamp": Date().timeIntervalSince1970
        ]
        AWAREEventLogger.shared().logEvent(eventDetails)

        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🚨 Error scheduling location notification: \(error)")
                AWAREEventLogger.shared().logEvent([
                    "class": "LocationHandler",
                    "event": "location_notification_failed",
                    "identifier": notificationIdentifier,
                    "error": error.localizedDescription
                ])
            } else {
                print("✅ Location notification scheduled with ID: \(notificationIdentifier)")
                AWAREEventLogger.shared().logEvent([
                    "class": "LocationHandler",
                    "event": "location_notification_added",
                    "identifier": notificationIdentifier
                ])

                // Ensure notification disappears after 15 minutes
                DispatchQueue.main.asyncAfter(deadline: .now() + 900) { // 900 seconds = 15 minutes
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
                    print("🗑️ Location notification expired and removed.")
                    AWAREEventLogger.shared().logEvent([
                        "class": "LocationHandler",
                        "event": "location_notification_expired",
                        "identifier": notificationIdentifier
                    ])
                }
            }
        }
    }




    func stopTimer() {
        timer?.invalidate()
        timer = nil
        startTime = nil
        currentNeighborhood = nil
    }

    // MARK: - Load Neighborhoods from GeoJSON
    func loadNeighborhoods() {
        if let fileURL = Bundle.main.url(forResource: "Neighborhoods-4", withExtension: "geojson") {
            do {
                let data = try Data(contentsOf: fileURL)
                let json = try JSONSerialization.jsonObject(with: data, options: [])

                guard let featureCollection = json as? [String: Any],
                      let features = featureCollection["features"] as? [[String: Any]] else { return }

                for feature in features {
                    if let properties = feature["properties"] as? [String: Any],
                       let neighborhoodName = properties["NAMELSAD"] as? String,
                       let geometry = feature["geometry"] as? [String: Any],
                       let coordinatesArray = geometry["coordinates"] as? [[[[Double]]]] {

                        let polygon = coordinatesArray[0][0].map {
                            CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
                        }
                        let mkPolygon = MKPolygon(coordinates: polygon, count: polygon.count)
                        neighborhoods[mkPolygon] = neighborhoodName
                    }
                }
            } catch {
                print("Error loading GeoJSON: \(error)")
            }
        }
    }

    func scheduleSurveys() {
        if hasScheduledSurveys { return }  // Prevent duplicate scheduling
        hasScheduledSurveys = true
        
        let currentHour = Calendar.current.component(.hour, from: Date())

        // Check if the current time falls within one of the survey time ranges
        var isWithinRange = false
        for range in timeRanges {
            if currentHour >= range.startHour && currentHour < range.endHour {
                isWithinRange = true
                break
            }
        }

        if isWithinRange {
            print("📅 Scheduling random survey notification within the valid time range.")
            
            // Add a delay to prevent immediate notifications on launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.sendRandomNotification()
            }
        } else {
            print("⏳ No survey scheduled yet. Current time is outside the allowed range.")
        }
    }


    // Function for sending a random notification
    func sendRandomNotification() {
        print("🔔 Sending random survey notification.")

        let content = UNMutableNotificationContent()
        content.title = "Your next Survey is ready (R)"
        content.body = " "
        content.sound = .default
        content.userInfo = [
            "url": "https://wustl.az1.qualtrics.com/jfe/form/SV_eK7CCmrAcKeNmLA",
            "invisibleText": "Random"
        ]
        content.categoryIdentifier = "surveyCategory"
        content.threadIdentifier = "surveyReminders"

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }

        let notificationIdentifier = UUID().uuidString
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)

        // Store event in AWAREEventLogger
        let eventDetails: [String: Any] = [
            "class": "AppDelegate",
            "event": "random_notification_scheduled",
            "identifier": notificationIdentifier,
            "title": content.title,
            "body": content.body,
            "url": content.userInfo["url"] as! String,
            "timestamp": Date().timeIntervalSince1970
        ]
        AWAREEventLogger.shared().logEvent(eventDetails)

        // Schedule the notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🚨 Error scheduling random notification: \(error)")
                AWAREEventLogger.shared().logEvent([
                    "class": "AppDelegate",
                    "event": "random_notification_failed",
                    "identifier": notificationIdentifier,
                    "error": error.localizedDescription
                ])
            } else {
                print("✅ Random notification scheduled with ID: \(notificationIdentifier)")
                AWAREEventLogger.shared().logEvent([
                    "class": "AppDelegate",
                    "event": "random_notification_added",
                    "identifier": notificationIdentifier
                ])

                // Ensure notification disappears after 15 minutes
                DispatchQueue.main.asyncAfter(deadline: .now() + 900) { // 900 seconds = 15 minutes
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
                    print("🗑️ Random notification expired and removed.")
                    AWAREEventLogger.shared().logEvent([
                        "class": "AppDelegate",
                        "event": "random_notification_expired",
                        "identifier": notificationIdentifier
                    ])
                }
            }
        }
    }
}
