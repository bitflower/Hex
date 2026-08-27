import AVFoundation
import Foundation
import HexCore

private let recoveryLogger = HexLog.recording

/// Recovers recordings stranded in the temp directory.
///
/// Audio is captured into `tmp/hex-recording-<uuid>.wav` and only moved into the
/// durable Recordings folder once transcription resolves. If the app is killed
/// or crashes mid-transcription the file is left behind — and iOS purges `tmp/`
/// without warning and never includes it in device backups, so a stranded file
/// is a recording on borrowed time.
///
/// This sweep runs at launch and adopts anything stranded there as a failed
/// history entry the user can play, share, or retry.
enum OrphanedRecordingRecovery {
  private static let strandedPrefix = "hex-recording-"

  /// Anything shorter than this is an accidental tap rather than lost speech.
  /// Adopting those would litter the history with empty entries, so they are
  /// discarded instead.
  private static let minimumRecoverableDuration: TimeInterval = 0.5

  /// Bytes per second the recorder writes: 16 kHz mono Float32.
  private static let bytesPerSecond: Double = 16000 * 4

  /// Adopts every stranded recording and returns them newest-first.
  ///
  /// Safe to run only at launch: a recording that is merely *in flight* also has
  /// a file under this prefix, so sweeping while the app is live would steal it
  /// out from under the running transcription.
  static func recoverStrandedRecordings() -> [Transcript] {
    let fm = FileManager.default
    let tmp = fm.temporaryDirectory

    guard let entries = try? fm.contentsOfDirectory(
      at: tmp,
      includingPropertiesForKeys: [.creationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    let stranded = entries.filter {
      $0.lastPathComponent.hasPrefix(strandedPrefix) && $0.pathExtension.lowercased() == "wav"
    }
    guard !stranded.isEmpty else { return [] }

    recoveryLogger.notice("Recovering \(stranded.count) stranded recording(s) from temp")

    var recovered: [Transcript] = []
    for url in stranded {
      let recordedAt = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
      let duration = audioDuration(of: url) ?? 0

      guard duration >= minimumRecoverableDuration else {
        // Drop it, otherwise it is re-examined on every future launch.
        recoveryLogger.notice("Discarding stranded recording of \(duration, format: .fixed(precision: 2))s")
        try? fm.removeItem(at: url)
        continue
      }

      do {
        let finalURL = try RecordingStore.adopt(url)
        recovered.append(
          Transcript(
            timestamp: recordedAt,
            text: "",
            audioPath: finalURL,
            duration: duration,
            failureReason: "Transcription was interrupted. The recording was recovered."
          )
        )
      } catch {
        recoveryLogger.error("Failed to adopt stranded recording: \(error.localizedDescription)")
      }
    }

    return recovered.sorted { $0.timestamp > $1.timestamp }
  }

  /// Deletes stranded recordings without adopting them. Used when the user has
  /// history turned off and has therefore asked us not to keep audio around.
  static func discardStrandedRecordings() {
    let fm = FileManager.default
    guard let entries = try? fm.contentsOfDirectory(
      at: fm.temporaryDirectory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else { return }

    for url in entries where url.lastPathComponent.hasPrefix(strandedPrefix)
      && url.pathExtension.lowercased() == "wav" {
      try? fm.removeItem(at: url)
    }
  }

  private static func audioDuration(of url: URL) -> TimeInterval? {
    if let file = try? AVAudioFile(forReading: url) {
      let sampleRate = file.processingFormat.sampleRate
      if sampleRate > 0 {
        return Double(file.length) / sampleRate
      }
    }
    // The header may be truncated if the app died mid-write, but the samples
    // are still there. Estimate from size so a long recording is not mistaken
    // for an empty one and discarded.
    guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 else {
      return nil
    }
    return Double(size) / bytesPerSecond
  }
}
