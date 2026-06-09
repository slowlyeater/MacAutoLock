import Foundation
#if SWIFT_PACKAGE
import MacAutoLockShared
#endif
@preconcurrency import WatchConnectivity

final class iOSWatchRelay: NSObject, WCSessionDelegate {
    var onLockRequest: (() -> Void)?

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendStatus(_ status: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["status": status], replyHandler: nil)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message["command"] as? String == ControlCommandKind.lockNow.rawValue {
            onLockRequest?()
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
