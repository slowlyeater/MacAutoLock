import Foundation
import Testing
@testable import MacAutoLockShared

@Test
func commandCodecRoundTripsEnvelope() throws {
    let senderId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let peerId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let envelope = CommandEnvelope(
        commandId: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        timestamp: Date(timeIntervalSince1970: 1_717_171_717),
        senderDeviceId: senderId,
        senderRole: .iphone,
        command: ControlCommand(
            kind: .heartbeat,
            peer: PeerState(
                id: peerId,
                deviceName: "Eric iPhone",
                role: .iphone,
                lastHeartbeat: Date(timeIntervalSince1970: 1_717_171_717),
                isConnected: true,
                isTrusted: true
            ),
            rule: AutoLockRule(),
            pairingCode: "123456"
        )
    )

    let codec = CommandCodec()
    let data = try codec.encode(envelope)
    let decoded = try codec.decode(data)

    #expect(decoded == envelope)
}

@Test
func commandCodecRejectsUnsupportedSchema() throws {
    let envelope = CommandEnvelope(
        schemaVersion: 999,
        senderDeviceId: UUID(),
        senderRole: .watch,
        command: ControlCommand(kind: .lockNow)
    )

    let codec = CommandCodec()
    let data = try codec.encode(envelope)

    #expect(throws: CommandCodecError.unsupportedSchemaVersion(999)) {
        try codec.decode(data)
    }
}
