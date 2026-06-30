import Foundation

struct MacLockController {
    func lockScreen() -> Bool {
        let strategies: [(String, [String])] = [
            (
                "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession",
                ["-suspend"]
            ),
            (
                "/usr/bin/osascript",
                ["-e", #"tell application "System Events" to keystroke "q" using {control down, command down}"#]
            ),
            (
                "/usr/bin/pmset",
                ["displaysleepnow"]
            )
        ]

        for (path, arguments) in strategies where FileManager.default.isExecutableFile(atPath: path) {
            if run(path: path, arguments: arguments) {
                return true
            }
        }

        return false
    }

    private func run(path: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            NSLog("MacAutoLock failed to lock screen: \(error.localizedDescription)")
            return false
        }
    }
}
