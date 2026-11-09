import SwiftUI
import UIKit

@main
struct WeatherGZApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = WeatherStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onOpenURL { url in
                    if url.scheme == "weathergz" {
                        Task { await store.refresh() }
                    }
                }
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        Task { await store.refreshIfNeeded() }
                        store.startAutoRefresh()
                    default:
                        store.stopAutoRefresh()
                    }
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BackgroundRefresh.register()
        return true
    }
}

/// 后台刷新：BGTaskScheduler，目标间隔 10 分钟（实际受系统调度）
enum BackgroundRefresh {
    static let taskIdentifier = "cn.guizhou.weathergz.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            let bg = UIApplication.shared.beginBackgroundTask(withName: taskIdentifier)
            Task {
                await WeatherStore.shared.refresh()
                await MainActor.run {
                    refreshTask.setTaskCompleted(success: true)
                    UIApplication.shared.endBackgroundTask(bg)
                    schedule()
                }
            }
        }
        schedule()
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: WeatherStore.refreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }
}
