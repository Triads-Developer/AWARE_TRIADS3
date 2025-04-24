//
//  AppDelegate.swift
//  aware-client-ios-v2
//
//  Created by Yuuki Nishiyama on 2019/02/27.
//  Copyright © 2019 Yuuki Nishiyama. All rights reserved.
//  Updated with NotificationLogger documentation by Jessie Walker on 2025/04/15

/// AppDelegate coordinates all app-level behaviors including lifecycle events, sensor setup,
/// push notification scheduling, and integration with the AWARE Framework and NotificationLogger.
///
/// This version includes complete documentation of how notification events are scheduled, delivered,
/// logged, and expired using NotificationLogger.


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
class AppDelegate: UIResponder, UIApplicationDelegate {
    /// Called when the application finishes launching.
    /// Sets up sensors, permissions, and notification scheduling, and initializes NotificationLogger
    var window: UIWindow?
    var lastLoggedNotificationId: String?
    var notificationCleanupTimer: Timer?
    var loggedNotificationEvents: Set<String> = []
    
    func getUrl() -> String {
        return "http://ec2-3-15-38-212.us-east-2.compute.amazonaws.com:8080/index.php/1/4lph4num3ric"
    }
    /// Defines the daily notification windows for survey delivery
    let timeRanges = [
        (startHour: 9, startMinute: 0, endHour: 11, endMinute: 0),
        (startHour: 11, startMinute: 0, endHour: 13, endMinute: 0),
        (startHour: 13, startMinute: 0, endHour: 17, endMinute: 0),
        (startHour: 17, startMinute: 0, endHour: 21, endMinute: 0)
    ]

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let core = AWARECore.shared()
        let manager = AWARESensorManager.shared()
        let study = AWAREStudy.shared()
        let studyurl = getUrl()

        let activity = IOSActivityRecognition(awareStudy: study)
        let location = Locations(awareStudy: study)
        let fuslocation = FusedLocations(awareStudy: study)
        let battery1 = Battery(awareStudy: study)
        let acc = Accelerometer(awareStudy: study)
        let blue = Bluetooth(awareStudy: study)
        let devices = DeviceUsage(awareStudy: study)
        let calls = Calls(awareStudy: study)

        study.setStudyURL(studyurl)

        manager.add(activity)
        manager.add(location)
        manager.add(fuslocation)
        manager.add(battery1)
        manager.add(acc)
        manager.add(blue)
        manager.add(calls)
        manager.add(devices)
        manager.add(AWAREEventLogger.shared()) // 🔧 Consolidated
        manager.add(AWAREStatusMonitor.shared()) // 🔧 Consolidated

        fuslocation.startSensor(withInterval: 1)
        fuslocation.saveAll = true
        location.saveAll = true
        manager.addSensors(with: study)

        fuslocation.setSensorEventHandler { (sensor, data) in
            fuslocation.startSyncDB()
            location.startSyncDB()
            print(data)
        }

        if manager.getAllSensors().count > 0 {
            core.setAnchor()
            if let fitbit = manager.getSensor(SENSOR_PLUGIN_FITBIT) as? Fitbit {
                fitbit.viewController = window?.rootViewController
            }

            core.activate()

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                print("🔐 Push permission granted: \(granted)")
            }

            core.requestPermissionForPushNotification { (_, _) in }
        }

        let surveyCategory = UNNotificationCategory(
            identifier: "RANDOM_SURVEY_CATEGORY",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([surveyCategory])
        UNUserNotificationCenter.current().delegate = self

        IOSESM.setESMAppearedState(false)
        let key = "aware-client-v2.setting.key.is-not-first-time"
        if !UserDefaults.standard.bool(forKey: key) {
            study.setCleanOldDataType(cleanOldDataTypeNever)
            UserDefaults.standard.set(true, forKey: key)
        }

        if UserDefaults.standard.bool(forKey: AdvancedSettingsIdentifiers.statusMonitor.rawValue) {
            AWAREStatusMonitor.shared().activate(withCheckInterval: 60)
        }

        AWAREEventLogger.shared().logEvent([
            "class": "AppDelegate",
            "event": "application:didFinishLaunchingWithOptions:launchOptions:"
        ])

        scheduleSevenDaysOfRandomSurveyNotifications()
        generateRandomTestNotification()
        cleanUpExpiredNotifications()
        startNotificationCleanupTimer()
        removeExpiredNotifications()
        initializeAWAREFrameworkComponents()
        LocationHandler.shared.startPeriodicLocationChecks()

        return true
    }

    

    func removeExpiredNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let now = Date()
            for notification in notifications {
                if let timestamp = notification.request.content.userInfo["creationTime"] as? TimeInterval {
                    let createdAt = Date(timeIntervalSince1970: timestamp)
                    if now.timeIntervalSince(createdAt) > 15 * 60 {
                        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
                        print("🗑 Removed expired notification: \(notification.request.identifier)")
                    }
                }
            }
        }
    }

    
    

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        AWAREEventLogger.shared().logEvent(["class":"AppDelegate",
                                            "event":"applicationWillResignActive:"]);
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        IOSESM.setESMAppearedState(false)
        UIApplication.shared.applicationIconBadgeNumber = 0
        AWAREEventLogger.shared().logEvent(["class":"AppDelegate",
                                            "event":"applicationDidEnterBackground:"]);
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        AWAREEventLogger.shared().logEvent(["class":"AppDelegate",
                                            "event":"applicationWillEnterForeground:"]);
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        AWAREEventLogger.shared().logEvent(["class":"AppDelegate",
                                            "event":"applicationDidBecomeActive:"]);
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        AWAREUtils.sendLocalPushNotification(withTitle: NSLocalizedString("terminate_title" , comment: ""),
                                             body: NSLocalizedString("terminate_msg" , comment: ""),
                                             timeInterval: 1,
                                             repeats: false)
        AWAREEventLogger.shared().logEvent(["class":"AppDelegate",
                                            "event":"applicationWillTerminate:"]);
        self.saveContext()
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        AWAREEventLogger.shared().logEvent(["class":"AppDelegate",
                                            "event":"application:open:options"]);
        
        if url.scheme == "fitbit" {
            let manager = AWARESensorManager.shared()
            if let fitbit = manager.getSensor(SENSOR_PLUGIN_FITBIT) as? Fitbit {
                fitbit.handle(url, sourceApplication: nil, annotation: options)
            }
        } else if url.scheme == "aware-ssl" || url.scheme == "aware" {
            var studyURL = url.absoluteString
            if studyURL.prefix(9) == "aware-ssl" {
                let range = studyURL.range(of: "aware-ssl")
                if let range = range {
                    studyURL = studyURL.replacingCharacters(in: range, with: "https")
                }
            } else if studyURL.prefix(5) == "aware" {
                let range = studyURL.range(of: "aware")
                if let range = range {
                    studyURL = studyURL.replacingCharacters(in: range, with: "http")
                }
            }
            let study = AWAREStudy.shared()
             study.join(withURL: studyURL) { (settings, status, error) in
                if status == AwareStudyStateUpdate || status == AwareStudyStateNew {
                    let core = AWARECore.shared()
                    core.requestPermissionForPushNotification { (notifState, error) in
                        core.requestPermissionForBackgroundSensing{ (locStatus) in
                            core.activate()
                            let manager = AWARESensorManager.shared()
                            manager.stopAndRemoveAllSensors()
                            manager.addSensors(with: study)
                            if let fitbit = manager.getSensor(SENSOR_PLUGIN_FITBIT) as? Fitbit {
                                fitbit.viewController = self.window?.rootViewController
                            }
                            manager.add(AWAREEventLogger.shared())
                            manager.add(AWAREStatusMonitor.shared())
                            manager.startAllSensors()
                            manager.createDBTablesOnAwareServer()
                        }
                    }
                }else {
                    // print("Error: ")
                }
            }
        }
        
        return true
    }

    //Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "aware_client_ios_v2")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    //Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                openSettingsFor notification: UNNotification?) {
        // Optional: Handle when user taps "Settings" from notification
    }

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
                case "OPEN_RANDOM_SURVEY", UNNotificationDefaultActionIdentifier:
                    return ("notification_opened", "Opened")
                case "DISMISS_RANDOM_SURVEY", UNNotificationDismissActionIdentifier:
                    return ("notification_dismissed", "Dismissed")
                default:
                    return ("notification_unknown_interaction", response.actionIdentifier)
            }
        }()

        // ✅ Log using NotificationLogger
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

        // ✅ Open URL if needed
        if event == "notification_opened", let url = URL(string: urlString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }

        completionHandler()
    }



    
    
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        let identifier = notification.request.identifier
        let content = notification.request.content
        let userInfo = content.userInfo

        let notificationType = userInfo["event_type"] as? String ?? "RANDOM_SURVEY"

        NotificationLogger.shared.logEventOnce(
            eventCategory: "random_notification",
            event: "notification_delivered",
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

    
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let userInfo = userInfo as? [String:Any]{
            // SilentPushManager().executeOperations(userInfo)
            PushNotificationResponder().response(withPayload: userInfo)
        }
        
        if AWAREStudy.shared().isDebug(){ print("didReceiveRemoteNotification:start") }
        
        let dispatchTime = DispatchTime.now() + 20
        DispatchQueue.main.asyncAfter( deadline: dispatchTime ) {
            
            if AWAREStudy.shared().isDebug(){ print("didReceiveRemoteNotification:end") }
            
            completionHandler(.noData)
        }
    }
    
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let push = PushNotification(awareStudy: AWAREStudy.shared())
        push.saveDeviceToken(with: deviceToken)
        push.startSyncDB()
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        
    }
    
//New Code ---------------------
    func scheduleSevenDaysOfRandomSurveyNotifications() {
        let formatter = ISO8601DateFormatter()

        // Check for existing schedule and timestamp
        if let timestamp = UserDefaults.standard.object(forKey: "schedule_timestamp") as? Date,
           let saved = UserDefaults.standard.object(forKey: "scheduled_notifications") as? [String] {

            let diff = Calendar.current.dateComponents([.day], from: timestamp, to: Date()).day ?? 0

            if diff < 7 && !saved.isEmpty {
                print("🛑 7-day notification schedule already exists. Skipping regeneration.")
                return
            } else {
                print("🧹 Schedule expired or empty. Clearing old data.")
                UserDefaults.standard.removeObject(forKey: "schedule_timestamp")
                UserDefaults.standard.removeObject(forKey: "scheduled_notifications")
                UserDefaults.standard.removeObject(forKey: "random_schedule_logged") // Reset flag
            }
        }

        print("📅 Creating new 7-day notification schedule.")
        var scheduledDates: [String] = []
        let calendar = Calendar.current

        for dayOffset in 0..<7 {
            for range in timeRanges {
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
                dateComponents.day! += dayOffset
                dateComponents.hour = range.startHour
                dateComponents.minute = range.startMinute

                guard let startTime = calendar.date(from: dateComponents) else { continue }

                var endComponents = dateComponents
                endComponents.hour = range.endHour
                endComponents.minute = range.endMinute

                guard let endTime = calendar.date(from: endComponents) else { continue }

                let interval = endTime.timeIntervalSince(startTime)
                let randomInterval = TimeInterval(arc4random_uniform(UInt32(interval)))
                let randomDate = startTime.addingTimeInterval(randomInterval)

                scheduleNotification(for: randomDate)
                scheduledDates.append(formatter.string(from: randomDate))
            }
        }

        // Save schedule and timestamp
        UserDefaults.standard.set(scheduledDates, forKey: "scheduled_notifications")
        UserDefaults.standard.set(Date(), forKey: "schedule_timestamp")
        print("✅ Notification schedule stored successfully.")

        // ✅ Log the schedule creation ONCE with a distinctive class name
        if !UserDefaults.standard.bool(forKey: "random_schedule_logged") {
            AWAREEventLogger.shared().logEvent([
                "Random": "Random_Notification_Schedule",
                "event": "random_notification_schedule_created",
                "timestamp": formatter.string(from: Date())
            ])
            print("📡 Logged: Random notification schedule created.")
            UserDefaults.standard.set(true, forKey: "random_schedule_logged")
            
            // 🔁 NEW: Log the entire 7-day schedule to AWAREEventLogger
            let scheduleLog: [String: Any] = [
                "random_notification_schedule": "full_schedule",
                "data": [
                    "schedule_id": UUID().uuidString,  // optional for traceability
                    "scheduled_dates": scheduledDates,
                    "device_id": AWAREStudy.shared().getDeviceId(),
                    "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                    "duration_days": 7
                ]
            ]
            AWAREEventLogger.shared().logEvent(scheduleLog)
            AWAREEventLogger.shared().startSyncDB()
            print("📡 Logged full 7-day notification schedule to AWARE database.")
        }
    }

    func scheduleNotification(for date: Date) {
        let identifier = UUID().uuidString

        let content = UNMutableNotificationContent()
        content.title = "Your next Survey is ready(R)"
        content.body = "  "
        content.sound = .default
        content.categoryIdentifier = "RANDOM_SURVEY_CATEGORY"
        content.badge = UIApplication.shared.applicationIconBadgeNumber + 1 as NSNumber
        content.userInfo = [
            "event_type": "random_survey_scheduled",
            "identifier": identifier,
            "url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"
        ]

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🚨 Notification scheduling error: \(error)")
            } else {
                // ✅ Log using centralized NotificationLogger
                NotificationLogger.shared.logEventOnce(
                    eventCategory: "random_notification",
                    event: "random_survey_scheduled",
                    identifier: identifier,
                    title: content.title,
                    body: content.body,
                    url: content.userInfo["url"] as? String, notificationType: "RANDOM_SURVEY"
                )

                // 🔧 Save timestamp for cleanup tracking
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "notification_timestamp_\(identifier)")

                // 🧼 Cleanup and trigger reminder after 5 minutes (300s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 900) {
                    UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                        let found = notifications.contains { $0.request.identifier == identifier }
                        if found {
                            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
                            
                            NotificationLogger.shared.logEventOnce(
                                eventCategory: "random_notification",
                                event: "notification_expired",
                                identifier: identifier,
                                title: content.title,
                                body: content.body,
                                url: content.userInfo["url"] as? String, notificationType: "RANDOM_SURVEY"
                            )

                            self.sendReminderNotification(originalIdentifier: identifier)
                            print("🧹 Primary notification expired and removed: \(identifier)")
                        } else {
                            print("ℹ️ Notification already dismissed or interacted with: \(identifier)")
                        }
                    }
                }
            }
        }
    }

    
    func sendReminderNotification(originalIdentifier: String) {
        let reminderIdentifier = "reminder_" + originalIdentifier

        let content = UNMutableNotificationContent()
        content.title = "⏳ Your next survey is ready(R)"
        content.body = "   "
        content.sound = .default
        content.categoryIdentifier = "RANDOM_SURVEY_CATEGORY"
        content.userInfo = [
            "event_type": "reminder_scheduled",
            "identifier": reminderIdentifier,
            "url": "https://wustl.az1.qualtrics.com/jfe/form/SV_0HyB20WVoAztGTk"
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🚨 Reminder scheduling error: \(error)")
            } else {
                // ✅ Log scheduled reminder with NotificationLogger
                NotificationLogger.shared.logEventOnce(
                    eventCategory: "random_notification",
                    event: "reminder_scheduled",
                    identifier: reminderIdentifier,
                    title: content.title,
                    body: content.body,
                    url: content.userInfo["url"] as? String, notificationType: "RANDOM_SURVEY"
                )

                // Save timestamp for expiration tracking
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "notification_timestamp_\(reminderIdentifier)")

                // Cleanup logic after 5 minutes
                DispatchQueue.main.asyncAfter(deadline: .now() + 900) {
                    UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                        let found = notifications.contains { $0.request.identifier == reminderIdentifier }
                        if found {
                            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reminderIdentifier])
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

                            NotificationLogger.shared.logEventOnce(
                                eventCategory: "random_notification",
                                event: "reminder_expired",
                                identifier: reminderIdentifier,
                                title: content.title,
                                body: content.body,
                                url: content.userInfo["url"] as? String, notificationType: "RANDOM_SURVEY"
                            )

                            print("🧹 Reminder notification expired and removed: \(reminderIdentifier)")
                        } else {
                            print("ℹ️ Reminder already dismissed or interacted with: \(reminderIdentifier)")
                        }
                    }
                }
            }
        }
    }

    

    


    func generateRandomTestNotification() {
        // Generate a random notification within the next minute
        let randomInterval = TimeInterval(arc4random_uniform(60) + 5) // between 5-65 sec from now
        let randomDate = Date().addingTimeInterval(randomInterval)
        
        scheduleNotification(for: randomDate)
        print("✅ Random test notification scheduled for \(randomDate)")
    }
    func cleanUpExpiredNotifications(expirationThreshold: TimeInterval = 900) {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let now = Date().timeIntervalSince1970
                var expiredIdentifiers: [String] = []

                for request in requests {
                    let identifier = request.identifier
                    let timestampKey = "notification_timestamp_\(identifier)"
                    if let timestamp = UserDefaults.standard.object(forKey: timestampKey) as? TimeInterval {
                        if now - timestamp > expirationThreshold {
                            expiredIdentifiers.append(identifier)
                            print("🧽 [Timer] Removing expired notification: \(identifier)")
                            UserDefaults.standard.removeObject(forKey: timestampKey)
                        }
                    }
                }

                if !expiredIdentifiers.isEmpty {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: expiredIdentifiers)
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: expiredIdentifiers)
                }
            }
        }

        func startNotificationCleanupTimer() {
            notificationCleanupTimer?.invalidate()
            notificationCleanupTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { _ in
                self.cleanUpExpiredNotifications()
            }
            RunLoop.main.add(notificationCleanupTimer!, forMode: .common)
        }
    
    
}
