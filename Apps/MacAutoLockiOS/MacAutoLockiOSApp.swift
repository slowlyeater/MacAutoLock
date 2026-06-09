import SwiftUI

@main
struct MacAutoLockiOSApp: App {
    @StateObject private var model = iOSAppModel()

    var body: some Scene {
        WindowGroup {
            iOSContentView()
                .environmentObject(model)
                .task {
                    model.start()
                }
        }
    }
}
