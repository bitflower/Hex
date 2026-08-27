import Dependencies
import Foundation

// MARK: - Recording store

/// The durable on-disk home for captured audio.
///
/// Recordings are captured into the app's temp directory, which iOS may purge at
/// any time and which is never included in device backups. Anything worth
/// keeping has to be moved out of there before the app goes idle — that is what
/// `adopt(_:)` is for.
public enum RecordingStore {
    /// `Application Support/com.kitlangton.Hex/Recordings`
    public static func recordingsFolder(create: Bool) throws -> URL {
        let fm = FileManager.default
        let supportDir = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: create
        )
        let folder = supportDir
            .appendingPathComponent("com.kitlangton.Hex", isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)
        if create {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    /// Moves a freshly-captured recording out of the purgeable temp directory
    /// into the Recordings folder, and returns its new location.
    public static func adopt(_ audioURL: URL) throws -> URL {
        let fm = FileManager.default
        let folder = try recordingsFolder(create: true)

        // Timestamp names match the historical scheme. Two files adopted in the
        // same instant (e.g. a startup sweep) would otherwise collide.
        let stem = "\(Date().timeIntervalSince1970)"
        var finalURL = folder.appendingPathComponent("\(stem).wav")
        var suffix = 1
        while fm.fileExists(atPath: finalURL.path) {
            finalURL = folder.appendingPathComponent("\(stem)-\(suffix).wav")
            suffix += 1
        }

        try fm.moveItem(at: audioURL, to: finalURL)
        return finalURL
    }
}

public extension Transcript {
    /// The audio file, resolved to a currently-valid on-disk location.
    ///
    /// iOS app containers get a fresh UUID between launches, so a stored
    /// absolute `audioPath` can be stale. If it is, reconstruct the path under
    /// the current container's Recordings folder using the original filename.
    func resolvedAudioURL() -> URL? {
        let fm = FileManager.default
        if fm.fileExists(atPath: audioPath.path) {
            return audioPath
        }
        guard let folder = try? RecordingStore.recordingsFolder(create: false) else {
            return nil
        }
        let reconstructed = folder.appendingPathComponent(audioPath.lastPathComponent)
        return fm.fileExists(atPath: reconstructed.path) ? reconstructed : nil
    }
}

// MARK: - Client

public struct TranscriptPersistenceClient: Sendable {
    public var save: @Sendable (
        _ result: String,
        _ audioURL: URL,
        _ duration: TimeInterval,
        _ sourceAppBundleID: String?,
        _ sourceAppName: String?
    ) async throws -> Transcript

    /// Persists a recording whose transcription failed. The audio is kept so the
    /// user can retry, play, or share it; `reason` is surfaced in the history UI.
    public var saveFailed: @Sendable (
        _ audioURL: URL,
        _ duration: TimeInterval,
        _ reason: String
    ) async throws -> Transcript

    public var deleteAudio: @Sendable (_ transcript: Transcript) async throws -> Void
}

extension TranscriptPersistenceClient: DependencyKey {
    public static let liveValue: TranscriptPersistenceClient = {
        return TranscriptPersistenceClient(
            save: { result, audioURL, duration, sourceAppBundleID, sourceAppName in
                let finalURL = try RecordingStore.adopt(audioURL)
                return Transcript(
                    timestamp: Date(),
                    text: result,
                    audioPath: finalURL,
                    duration: duration,
                    sourceAppBundleID: sourceAppBundleID,
                    sourceAppName: sourceAppName
                )
            },
            saveFailed: { audioURL, duration, reason in
                let finalURL = try RecordingStore.adopt(audioURL)
                return Transcript(
                    timestamp: Date(),
                    text: "",
                    audioPath: finalURL,
                    duration: duration,
                    failureReason: reason
                )
            },
            deleteAudio: { transcript in
                // Go through `resolvedAudioURL()` so a stale container path does
                // not silently leave the file behind.
                if let url = transcript.resolvedAudioURL() {
                    try FileManager.default.removeItem(at: url)
                }
            }
        )
    }()

    public static let testValue = TranscriptPersistenceClient(
        save: { _, _, _, _, _ in
            Transcript(timestamp: Date(), text: "", audioPath: URL(fileURLWithPath: "/"), duration: 0)
        },
        saveFailed: { _, _, reason in
            Transcript(
                timestamp: Date(),
                text: "",
                audioPath: URL(fileURLWithPath: "/"),
                duration: 0,
                failureReason: reason
            )
        },
        deleteAudio: { _ in }
    )
}

public extension DependencyValues {
    var transcriptPersistence: TranscriptPersistenceClient {
        get { self[TranscriptPersistenceClient.self] }
        set { self[TranscriptPersistenceClient.self] = newValue }
    }
}
