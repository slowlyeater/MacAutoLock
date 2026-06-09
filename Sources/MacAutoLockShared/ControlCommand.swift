import Foundation

public enum ControlCommandKind: String, Codable, CaseIterable, Sendable {
    case lockNow
    case heartbeat
    case stateRequest
    case stateResponse
    case unlockProbe
}

public struct ControlCommand: Codable, Equatable, Sendable {
    public var kind: ControlCommandKind
    public var lockState: LockState?
    public var peer: PeerState?
    public var rule: AutoLockRule?
    public var pairingCode: String?
    public var message: String?

    public init(
        kind: ControlCommandKind,
        lockState: LockState? = nil,
        peer: PeerState? = nil,
        rule: AutoLockRule? = nil,
        pairingCode: String? = nil,
        message: String? = nil
    ) {
        self.kind = kind
        self.lockState = lockState
        self.peer = peer
        self.rule = rule
        self.pairingCode = pairingCode
        self.message = message
    }
}

public struct CommandEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var commandId: UUID
    public var timestamp: Date
    public var senderDeviceId: UUID
    public var senderRole: DeviceRole
    public var command: ControlCommand

    public init(
        schemaVersion: Int = CommandEnvelope.currentSchemaVersion,
        commandId: UUID = UUID(),
        timestamp: Date = Date(),
        senderDeviceId: UUID,
        senderRole: DeviceRole,
        command: ControlCommand
    ) {
        self.schemaVersion = schemaVersion
        self.commandId = commandId
        self.timestamp = timestamp
        self.senderDeviceId = senderDeviceId
        self.senderRole = senderRole
        self.command = command
    }
}
