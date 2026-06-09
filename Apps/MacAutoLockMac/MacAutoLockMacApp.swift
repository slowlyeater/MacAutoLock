import SwiftUI

@main
struct MacAutoLockMacApp: App {
    @StateObject private var model: MacAppModel

    init() {
        let model = MacAppModel()
        _model = StateObject(wrappedValue: model)
        Task { @MainActor in
            model.start()
        }
    }

    var body: some Scene {
        MenuBarExtra("Mac AutoLock", systemImage: "lock.shield") {
            MacMenuView()
                .environmentObject(model)
                .frame(width: 320)
        }
        .menuBarExtraStyle(.window)
    }
}
