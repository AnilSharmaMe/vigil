import SwiftUI
import BackgroundTasks

@main
struct FaceCompareApp: App {
    
    init() {
        // Request notification permission at launch
        NotificationManager.shared.requestPermission()
        
        // Register background refresh task
        registerBackgroundTask()
        
        // Schedule the first refresh
        scheduleAppRefresh()
        
        // Testing
        WantedPhotoService.shared.refreshWantedPersons()
        RetailPersonService.shared.refreshWantedRetailPersons()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    // MARK: - Background Task Setup
    
    /// Register the background refresh task with iOS
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.safetyapp.refreshWantedList",
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    /// Handle the background refresh when iOS launches your app in the background
    func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh
        scheduleAppRefresh()
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = BlockOperation {
            // Fetch the wanted list
            WantedPhotoService.shared.refreshWantedPersons()
        }
        
        task.expirationHandler = {
            // Cancel operation if system kills task
            queue.cancelAllOperations()
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        
        queue.addOperation(operation)
    }
    
    /// Schedule a background refresh task
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.safetyapp.refreshWantedList")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour from now
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
}

