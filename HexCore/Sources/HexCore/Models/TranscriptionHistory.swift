import Foundation

public struct Transcript: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var text: String
    public var audioPath: URL
    public var duration: TimeInterval
    public var sourceAppBundleID: String?
    public var sourceAppName: String?
    public var savedToAppleNotes: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        text: String,
        audioPath: URL,
        duration: TimeInterval,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        savedToAppleNotes: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.audioPath = audioPath
        self.duration = duration
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.savedToAppleNotes = savedToAppleNotes
    }
}

extension Transcript: Codable {
    enum CodingKeys: String, CodingKey {
        case id, timestamp, text, audioPath, duration
        case sourceAppBundleID, sourceAppName
        case savedToAppleNotes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        text = try container.decode(String.self, forKey: .text)
        audioPath = try container.decode(URL.self, forKey: .audioPath)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        sourceAppBundleID = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
        sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        savedToAppleNotes = (try container.decodeIfPresent(Bool.self, forKey: .savedToAppleNotes)) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(text, forKey: .text)
        try container.encode(audioPath, forKey: .audioPath)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(sourceAppBundleID, forKey: .sourceAppBundleID)
        try container.encodeIfPresent(sourceAppName, forKey: .sourceAppName)
        try container.encode(savedToAppleNotes, forKey: .savedToAppleNotes)
    }
}

public struct TranscriptionHistory: Codable, Equatable, Sendable {
    public var history: [Transcript] = []
    
    public init(history: [Transcript] = []) {
        self.history = history
    }
}
