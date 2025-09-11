import SwiftUI
import BackgroundTasks

@main
struct NetraApp: App {
    
    init() {
        NotificationManager.shared.requestPermission()
        registerBackgroundTask()
        scheduleAppRefresh()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    DispatchQueue.global(qos: .userInitiated).async {
                        WantedPersonServiceManager.shared.refresh(category: EmbeddingCategory.regular)
                        WantedPersonServiceManager.shared.refresh(category: EmbeddingCategory.retail)
                        WantedPersonServiceManager.shared.refresh(category: EmbeddingCategory.unsolved)
                    }
                }
        }
    }
    
    // MARK: - Background
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
    
    func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()
        
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let operation = BlockOperation {
            WantedPersonServiceManager.shared.refresh(category: EmbeddingCategory.regular)
            WantedPersonServiceManager.shared.refresh(category: EmbeddingCategory.retail)
            WantedPersonServiceManager.shared.refresh(category: EmbeddingCategory.unsolved)
        }
        
        task.expirationHandler = { queue.cancelAllOperations() }
        operation.completionBlock = { task.setTaskCompleted(success: !operation.isCancelled) }
        queue.addOperation(operation)
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.safetyapp.refreshWantedList")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600) // 6 hours
        do { try BGTaskScheduler.shared.submit(request) }
        catch { print("Could not schedule refresh: \(error)") }
    }
}

