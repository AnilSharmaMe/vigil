import SwiftUI
import BackgroundTasks

@main
struct NetraApp: App {
    
    init() {
        // Request notification permission at launch
        NotificationManager.shared.requestPermission()
        
        // Register background refresh task
        registerBackgroundTask()
        
        // Schedule the first refresh
        scheduleAppRefresh()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Run initial refresh on launch without blocking UI
                    DispatchQueue.global(qos: .userInitiated).async {
                        WantedPersonServiceManager.shared.refresh(category: .regular)
                        WantedPersonServiceManager.shared.refresh(category: .retail)
                        WantedPersonServiceManager.shared.refresh(category: .unsolved)
                    }
                }
        }
    }
    
    // MARK: - Background Task Setup
    
    /// Register the background refresh task with iOS
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.safetyapp.refreshWantedList",
            using: nil
        ) { task in
            if let refreshTask = task as? BGAppRefreshTask {
                self.handleAppRefresh(task: refreshTask)
            }
        }
    }
    
    /// Handle the background refresh when iOS launches your app in the background
    func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh
        scheduleAppRefresh()
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = BlockOperation {
            // Refresh all categories in background
            WantedPersonServiceManager.shared.refresh(category: .regular)
            WantedPersonServiceManager.shared.refresh(category: .retail)
            WantedPersonServiceManager.shared.refresh(category: .unsolved)
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

