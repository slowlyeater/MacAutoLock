import Foundation
#if SWIFT_PACKAGE
import MacAutoLockShared
#endif
import SwiftUI
@preconcurrency import WatchConnectivity

@MainActor
final class WatchAppModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var status = "Ready"
    @Published var isReachable = false

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        isReachable = WCSession.default.isReachable
    }

    func lockNow() {
        guard WCSession.default.isReachable else {
            isReachable = false
            return
        }
        WCSession.default.sendMessage(["command": ControlCommandKind.lockNow.rawValue], replyHandler: nil)
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let receivedStatus = message["status"] as? String
        Task { @MainActor in
            if let receivedStatus {
                self.status = receivedStatus
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }
}
