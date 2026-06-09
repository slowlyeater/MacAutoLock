import SwiftUI

@main
struct MacAutoLockWatchApp: App {
    @StateObject private var model = WatchAppModel()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(model)
                .task {
                    model.start()
                }
        }
    }
}
