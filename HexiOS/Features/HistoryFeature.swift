import AVFoundation
import ComposableArchitecture
import Dependencies
import HexCore
import SwiftUI
import WhisperKit

private let historyLogger = HexLog.history

// MARK: - Date Extensions

extension Date {
  func relativeFormatted() -> String {
    let calendar = Calendar.current
    let now = Date()

    if calendar.isDateInToday(self) {
      return "Today"
    } else if calendar.isDateInYesterday(self) {
      return "Yesterday"
    } else if let daysAgo = calendar.dateComponents([.day], from: self, to: now).day, daysAgo < 7 {
      let formatter = DateFormatter()
      formatter.dateFormat = "EEEE"
      return formatter.string(from: self)
    } else {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .none
      return formatter.string(from: self)
    }
  }
}

// MARK: - Models

extension SharedReaderKey
  where Self == FileStorageKey<TranscriptionHistory>.Default
{
  static var transcriptionHistory: Self {
    Self[
      .fileStorage(.transcriptionHistoryURL),
      default: .init()
    ]
  }
}

extension URL {
  static var transcriptionHistoryURL: URL {
    get {
      let newURL = (try? URL.hexApplicationSupport.appending(component: "transcription_history.json"))
        ?? URL.documentsDirectory.appending(component: "transcription_history.json")
      return newURL
    }
  }
}

class AudioPlayerController: NSObject, AVAudioPlayerDelegate {
  private var player: AVAudioPlayer?
  var onPlaybackFinished: (() -> Void)?

  func play(url: URL) throws -> AVAudioPlayer {
    let player = try AVAudioPlayer(contentsOf: url)
    player.delegate = self
    player.play()
    self.player = player
    return player
  }

  func stop() {
    player?.stop()
    player = nil
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    self.player = nil
    Task { @MainActor in
      onPlaybackFinished?()
    }
  }
}

// MARK: - History Feature

@Reducer
struct HistoryFeature {
  @ObservableState
  struct State: Equatable {
    @Shared(.hexSettings) var hexSettings: HexSettings
    @Shared(.transcriptionHistory) var transcriptionHistory: TranscriptionHistory
    var playingTranscriptID: UUID?
    var audioPlayer: AVAudioPlayer?
    var audioPlayerController: AudioPlayerController?
    /// Entries whose transcription is currently being retried.
    var retryingTranscriptIDs: Set<UUID> = []

    mutating func stopAudioPlayback() {
      audioPlayerController?.stop()
      audioPlayer = nil
      audioPlayerController = nil
      playingTranscriptID = nil
    }
  }

  enum Action {
    case playTranscript(UUID)
    case stopPlayback
    case copyToClipboard(String)
    case saveToAppleNotes(String, transcriptID: UUID?)
    case appendToAppleNote(String, transcriptID: UUID?)
    case deleteTranscript(UUID)
    case deleteSelected(Set<UUID>)
    case playbackFinished
    case navigateToSettings
    case openTranscript(text: String, refinedText: String?)
    case retryTranscript(UUID)
    case retrySucceeded(id: UUID, text: String)
    case retryFailed(id: UUID, reason: String)
  }

  @Dependency(\.pasteboard) var pasteboard
  @Dependency(\.appleNotes) var appleNotes
  @Dependency(\.transcription) var transcription
  @Dependency(\.transcriptPersistence) var transcriptPersistence

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .playTranscript(id):
        if state.playingTranscriptID == id {
          state.stopAudioPlayback()
          return .none
        }

        state.stopAudioPlayback()

        guard let transcript = state.transcriptionHistory.history.first(where: { $0.id == id }) else {
          return .none
        }

        // iOS container UUIDs change between launches, so stored absolute paths
        // may be stale. `resolvedAudioURL()` handles the fallback.
        guard let audioURL = transcript.resolvedAudioURL() else {
          historyLogger.error("Cannot resolve audio path for transcript \(id)")
          return .none
        }

        do {
          let controller = AudioPlayerController()
          let player = try controller.play(url: audioURL)
          state.audioPlayer = player
          state.audioPlayerController = controller
          state.playingTranscriptID = id

          return .run { send in
            await withCheckedContinuation { continuation in
              controller.onPlaybackFinished = {
                continuation.resume()
                Task { @MainActor in
                  send(.playbackFinished)
                }
              }
            }
          }
        } catch {
          historyLogger.error("Failed to play audio: \(error.localizedDescription)")
          return .none
        }

      case .stopPlayback, .playbackFinished:
        state.stopAudioPlayback()
        return .none

      case let .copyToClipboard(text):
        return .run { [pasteboard] _ in
          await pasteboard.copy(text)
        }

      case let .saveToAppleNotes(text, transcriptID):
        if let transcriptID {
          state.$transcriptionHistory.withLock { history in
            if let index = history.history.firstIndex(where: { $0.id == transcriptID }) {
              history.history[index].savedToNotes = true
            }
          }
        }
        let folderName = state.hexSettings.appleNotesFolderName
        return .run { [appleNotes] _ in
          try? await appleNotes.saveNote(text, folderName)
        }

      case let .appendToAppleNote(text, transcriptID):
        if let transcriptID {
          state.$transcriptionHistory.withLock { history in
            if let index = history.history.firstIndex(where: { $0.id == transcriptID }) {
              history.history[index].savedToNotes = true
            }
          }
        }
        return .run { [appleNotes] _ in
          try? await appleNotes.appendToNote(text)
        }

      case let .deleteTranscript(id):
        guard let index = state.transcriptionHistory.history.firstIndex(where: { $0.id == id }) else {
          return .none
        }
        let transcript = state.transcriptionHistory.history[index]
        if state.playingTranscriptID == id {
          state.stopAudioPlayback()
        }
        state.retryingTranscriptIDs.remove(id)
        _ = state.$transcriptionHistory.withLock { history in
          history.history.remove(at: index)
        }
        return .run { [transcriptPersistence] _ in
          try? await transcriptPersistence.deleteAudio(transcript)
        }

      case let .deleteSelected(ids):
        let toDelete = state.transcriptionHistory.history.filter { ids.contains($0.id) }
        if let playingID = state.playingTranscriptID, ids.contains(playingID) {
          state.stopAudioPlayback()
        }
        state.retryingTranscriptIDs.subtract(ids)
        state.$transcriptionHistory.withLock { history in
          history.history.removeAll { ids.contains($0.id) }
        }
        return .run { [transcriptPersistence] _ in
          for transcript in toDelete {
            try? await transcriptPersistence.deleteAudio(transcript)
          }
        }

      case .navigateToSettings:
        return .none

      case .openTranscript:
        // Handled by parent (IOSAppFeature)
        return .none

      // MARK: - Retrying a failed transcription

      case let .retryTranscript(id):
        guard !state.retryingTranscriptIDs.contains(id),
              let transcript = state.transcriptionHistory.history.first(where: { $0.id == id })
        else { return .none }

        guard let audioURL = transcript.resolvedAudioURL() else {
          historyLogger.error("Cannot resolve audio path to retry transcript \(id)")
          return .send(.retryFailed(id: id, reason: "The recording could not be found on disk."))
        }

        state.retryingTranscriptIDs.insert(id)

        let settings = state.hexSettings
        let model = settings.selectedModel
        let language = settings.outputLanguage
        // Date-prefix from the original recording, not from now, so a retry
        // reproduces what the first attempt would have written.
        let recordedAt = transcript.timestamp

        return .run { [transcription] send in
          do {
            var options = DecodingOptions()
            if let language, !language.isEmpty {
              options.language = language
            }
            let raw = try await transcription.transcribe(audioURL, model, options) { _ in }
            let text = TranscriptTextPostProcessor.normalizeWithDatePrefix(
              raw,
              settings: settings,
              date: recordedAt
            )
            await send(.retrySucceeded(id: id, text: text))
          } catch {
            historyLogger.error("Retry failed: \(error.localizedDescription)")
            await send(.retryFailed(id: id, reason: error.localizedDescription))
          }
        }

      case let .retrySucceeded(id, text):
        state.retryingTranscriptIDs.remove(id)
        state.$transcriptionHistory.withLock { history in
          if let index = history.history.firstIndex(where: { $0.id == id }) {
            history.history[index].text = text
            history.history[index].failureReason = nil
          }
        }
        return .none

      case let .retryFailed(id, reason):
        state.retryingTranscriptIDs.remove(id)
        state.$transcriptionHistory.withLock { history in
          if let index = history.history.firstIndex(where: { $0.id == id }) {
            history.history[index].failureReason = reason
          }
        }
        return .none
      }
    }
  }
}
