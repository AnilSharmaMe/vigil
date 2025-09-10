import Foundation
import UserNotifications
import CoreLocation

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // Request permission for notifications
    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if let error = error {
                    print("Notification permission error: \(error)")
                } else {
                    print("Notifications granted: \(granted)")
                }
            }
    }
    
    // Show notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    // Generic notification
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error)")
            } else {
                print("Notification scheduled successfully")
            }
        }
    }
    
    // Notification for face match with location
    func sendMatchNotification(with match: FaceMatch) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Unwanted Person Detected"
        content.body = "Match: \(match.key) detected nearby"
        content.sound = .default

        // Save UIImage to temporary file
        if let imageData = match.image.jpegData(compressionQuality: 0.8) {
            let tmpDir = FileManager.default.temporaryDirectory
            let fileURL = tmpDir.appendingPathComponent("\(match.key).jpg")
            try? imageData.write(to: fileURL)

            // Create attachment
            if let attachment = try? UNNotificationAttachment(identifier: "matchImage", url: fileURL, options: nil) {
                content.attachments = [attachment]
            }
        }

        // Trigger immediately
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            } else {
                print("Notification sent with image!")
            }
        }
    }
}

