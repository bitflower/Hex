import Foundation

public struct Transcript: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var text: String
    public var refinedText: String?
    public var audioPath: URL
    public var duration: TimeInterval
    public var sourceAppBundleID: String?
    public var sourceAppName: String?
    public var savedToNotes: Bool?
    /// Non-nil when transcription failed for this recording. The audio is kept
    /// anyway so the user can play, share, or retry it instead of losing the
    /// take. Optional so history written before this existed still decodes.
    public var failureReason: String?

    /// Whether this entry is a recording whose transcription never produced text.
    public var didFail: Bool { failureReason != nil }

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        text: String,
        refinedText: String? = nil,
        audioPath: URL,
        duration: TimeInterval,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        savedToNotes: Bool = false,
        failureReason: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.refinedText = refinedText
        self.audioPath = audioPath
        self.duration = duration
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.savedToNotes = savedToNotes
        self.failureReason = failureReason
    }
}

public struct TranscriptionHistory: Codable, Equatable, Sendable {
    public var history: [Transcript] = []
    
    public init(history: [Transcript] = []) {
        self.history = history
    }
}
