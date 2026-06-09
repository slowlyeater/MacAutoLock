import Foundation

public enum CommandCodecError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
}

public struct CommandCodec: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = encoder
        self.decoder = decoder
    }

    public func encode(_ envelope: CommandEnvelope) throws -> Data {
        try encoder.encode(envelope)
    }

    public func decode(_ data: Data) throws -> CommandEnvelope {
        let envelope = try decoder.decode(CommandEnvelope.self, from: data)
        guard envelope.schemaVersion == CommandEnvelope.currentSchemaVersion else {
            throw CommandCodecError.unsupportedSchemaVersion(envelope.schemaVersion)
        }
        return envelope
    }
}
