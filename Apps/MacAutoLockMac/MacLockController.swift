import Foundation

struct MacLockController {
    func lockScreen() {
        let executable = URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
        let process = Process()
        process.executableURL = executable
        process.arguments = ["-suspend"]

        do {
            try process.run()
        } catch {
            NSLog("MacAutoLock failed to lock screen: \(error.localizedDescription)")
        }
    }
}
