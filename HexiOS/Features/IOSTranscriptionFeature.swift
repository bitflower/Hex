import AVFoundation
import ComposableArchitecture
import Dependencies
import HexCore
import UIKit
import WhisperKit

private let transcriptionLogger = HexLog.transcription

@Reducer
struct IOSTranscriptionFeature {
  @ObservableState
  struct State: Equatable {
    @Shared(.hexSettings) var hexSettings: HexSettings
    @Shared(.modelBootstrapState) var modelBootstrapState: ModelBootstrapState
    @Shared(.transcriptionHistory) var transcriptionHistory: TranscriptionHistory

    var isRecording = false
    var isTranscribing = false
    var isPrewarming = false
    var meter = Meter(averagePower: 0, peakPower: 0)
    var lastTranscriptionResult: String?
    var currentTranscriptID: UUID?
    var transcriptionError: String?
    var recordingStartTime: Date?

    // Append recording state
    var isAppendRecording = false
    var isAppendTranscribing = false
    var pendingAppendText: String?

    // AI refinement state
    enum RefinementStatus: Equatable {
      case idle
      case processing
      case completed(String)
      case failed

      var isProcessing: Bool {
        if case .processing = self { return true }
        return false
      }
    }
    var refinementStatus: RefinementStatus = .idle
  }

  enum Action {
    case task
    case startRecording
    case stopRecording
    case cancel
    case audioLevelUpdated(Meter)
    case transcriptionResult(String, URL)
    case transcriptionFailed(String)
    case copyResult
    case shareResult
    case saveToAppleNotes(String)
    case appendToAppleNote(String)
    case clearResult
    case openTranscript(String)
    case openTranscriptWithRefinement(String, String?)
    case prewarmCompleted

    // Append recording actions
    case startAppendRecording
    case stopAppendRecording
    case cancelAppendRecording
    case appendTranscriptionResult(String)
    case appendTranscriptionFailed
    case updateTranscriptionText(String)
    case updateRefinedText(String)

    // AI refinement actions
    case retriggerRefinement
    case refinementCompleted(String)
    case refinementFailed
  }

  @Dependency(\.recording) var recording
  @Dependency(\.transcription) var transcription
  @Dependency(\.soundEffects) var soundEffects
  @Dependency(\.continuousClock) var clock
  @Dependency(\.date) var date
  @Dependency(\.transcriptPersistence) var transcriptPersistence
  @Dependency(\.pasteboard) var pasteboard
  @Dependency(\.appleNotes) var appleNotes
  @Dependency(\.refinement) var refinement
  @Dependency(\.sleepManagement) var sleepManagement

  private static let datePrefixFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  enum CancelID {
    case metering
    case refinement
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .task:
        state.isPrewarming = true
        return .run { send in
          await soundEffects.preloadSounds()
          await recording.warmUpRecorder()
          await send(.prewarmCompleted)
        }

      case .prewarmCompleted:
        state.isPrewarming = false
        return .none

      case .startRecording:
        guard !state.isRecording, !state.isTranscribing,
              !state.isAppendRecording, !state.isAppendTranscribing else { return .none }
        state.isRecording = true
        state.lastTranscriptionResult = nil
        state.transcriptionError = nil
        state.refinementStatus = .idle
        state.recordingStartTime = date.now

        return .merge(
          .run { [sleepManagement, soundEffects] _ in
            await sleepManagement.preventSleep("Voice Recording")
            await recording.startRecording()
            soundEffects.play(.startRecording)
          },
          .run { send in
            let haptic = await UIImpactFeedbackGenerator(style: .medium)
            await haptic.impactOccurred()
            for await level in await recording.observeAudioLevel() {
              await send(.audioLevelUpdated(level))
            }
          }
          .cancellable(id: CancelID.metering)
        )

      case .stopRecording:
        guard state.isRecording else { return .none }
        state.isRecording = false
        state.isTranscribing = true
        soundEffects.play(.stopRecording)

        let model = state.hexSettings.selectedModel
        let language = state.hexSettings.outputLanguage
        let wordRemappings = state.hexSettings.wordRemappings
        let wordRemovals = state.hexSettings.wordRemovals
        let wordRemovalsEnabled = state.hexSettings.wordRemovalsEnabled
        let saveHistory = state.hexSettings.saveTranscriptionHistory
        let startTime = state.recordingStartTime
        let transcriptionHistory = state.$transcriptionHistory
        let maxHistoryEntries = state.hexSettings.maxHistoryEntries

        return .merge(
          .cancel(id: CancelID.metering),
          .run { [sleepManagement] send in
            await sleepManagement.allowSleep()
            let haptic = await UIImpactFeedbackGenerator(style: .light)
            await haptic.impactOccurred()

            let audioURL = await recording.stopRecording()
            let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0

            do {
              var options = DecodingOptions()
              if let language, !language.isEmpty {
                options.language = language
              }
              var text = try await transcription.transcribe(audioURL, model, options) { _ in }

              // Apply word removals
              if wordRemovalsEnabled {
                text = WordRemovalApplier.apply(text, removals: wordRemovals)
              }

              // Apply word remappings
              text = WordRemappingApplier.apply(text, remappings: wordRemappings)

              text = text.trimmingCharacters(in: .whitespacesAndNewlines)

              // Add date prefix (YYYY-MM-DD)
              text = Self.datePrefixFormatter.string(from: Date()) + " " + text

              // Save to history
              if saveHistory {
                if let transcript = try? await transcriptPersistence.save(text, audioURL, duration, nil, nil) {
                  transcriptionHistory.withLock { history in
                    history.history.insert(transcript, at: 0)

                    if let maxEntries = maxHistoryEntries, maxEntries > 0 {
                      while history.history.count > maxEntries {
                        if let removed = history.history.popLast() {
                          Task {
                            try? await transcriptPersistence.deleteAudio(removed)
                          }
                        }
                      }
                    }
                  }
                }
              } else {
                try? FileManager.default.removeItem(at: audioURL)
              }

              await send(.transcriptionResult(text, audioURL))
            } catch {
              transcriptionLogger.error("Transcription failed: \(error.localizedDescription)")
              await send(.transcriptionFailed(error.localizedDescription))
            }
          }
        )

      case .cancel:
        guard state.isRecording else { return .none }
        state.isRecording = false
        soundEffects.play(.cancel)
        return .merge(
          .cancel(id: CancelID.metering),
          .run { [sleepManagement] _ in
            await sleepManagement.allowSleep()
            _ = await recording.stopRecording()
            let haptic = await UINotificationFeedbackGenerator()
            await haptic.notificationOccurred(.warning)
          }
        )

      case .audioLevelUpdated(let meter):
        state.meter = meter
        return .none

      case .transcriptionResult(let text, _):
        state.isTranscribing = false
        state.lastTranscriptionResult = text
        state.currentTranscriptID = state.transcriptionHistory.history.first(where: { $0.text == text })?.id
        soundEffects.play(.pasteTranscript)
        // Trigger AI refinement
        if state.hexSettings.refinementEnabled && refinement.isAvailable() {
          state.refinementStatus = .processing
          let instructions = state.hexSettings.refinementInstructions
          let replacements = state.hexSettings.termReplacements
          return .run { send in
            let refined = try await refinement.refine(text, instructions, replacements)
            guard !refined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
              await send(.refinementFailed)
              return
            }
            await send(.refinementCompleted(refined))
          } catch: { _, send in
            await send(.refinementFailed)
          }
          .cancellable(id: CancelID.refinement)
        }
        return .none

      case .transcriptionFailed(let error):
        state.isTranscribing = false
        state.transcriptionError = error
        return .none

      case .copyResult:
        guard let text = state.lastTranscriptionResult else { return .none }
        return .run { _ in
          await pasteboard.copy(text)
          let haptic = await UINotificationFeedbackGenerator()
          await haptic.notificationOccurred(.success)
        }

      case .shareResult:
        return .none

      case .saveToAppleNotes(let text):
        guard !text.isEmpty else { return .none }
        // Mark transcript as saved to notes
        if let id = state.currentTranscriptID {
          state.$transcriptionHistory.withLock { history in
            if let index = history.history.firstIndex(where: { $0.id == id }) {
              history.history[index].savedToNotes = true
            }
          }
        }
        let folderName = state.hexSettings.appleNotesFolderName
        return .run { [appleNotes] _ in
          try? await appleNotes.saveNote(text, folderName)
          let haptic = await UINotificationFeedbackGenerator()
          await haptic.notificationOccurred(.success)
        }

      case .appendToAppleNote(let text):
        guard !text.isEmpty else { return .none }
        // Mark transcript as saved to notes
        if let id = state.currentTranscriptID {
          state.$transcriptionHistory.withLock { history in
            if let index = history.history.firstIndex(where: { $0.id == id }) {
              history.history[index].savedToNotes = true
            }
          }
        }
        return .run { [appleNotes] _ in
          try? await appleNotes.appendToNote(text)
          let haptic = await UINotificationFeedbackGenerator()
          await haptic.notificationOccurred(.success)
        }

      case .openTranscript(let text):
        state.lastTranscriptionResult = text
        state.currentTranscriptID = state.transcriptionHistory.history.first(where: { $0.text == text })?.id
        state.transcriptionError = nil
        return .none

      case .openTranscriptWithRefinement(let text, let refinedText):
        state.lastTranscriptionResult = text
        state.currentTranscriptID = state.transcriptionHistory.history.first(where: { $0.text == text })?.id
        state.transcriptionError = nil
        if let refinedText {
          state.refinementStatus = .completed(refinedText)
        } else {
          state.refinementStatus = .idle
        }
        return .none

      case .clearResult:
        let wasAppendRecording = state.isAppendRecording
        state.lastTranscriptionResult = nil
        state.currentTranscriptID = nil
        state.transcriptionError = nil
        state.pendingAppendText = nil
        state.refinementStatus = .idle
        state.isAppendTranscribing = false
        state.isAppendRecording = false
        if wasAppendRecording {
          return .merge(
            .cancel(id: CancelID.metering),
            .cancel(id: CancelID.refinement),
            .run { _ in
              _ = await recording.stopRecording()
            }
          )
        }
        return .cancel(id: CancelID.refinement)

      // MARK: - Append Recording

      case .startAppendRecording:
        guard !state.isRecording, !state.isTranscribing,
              !state.isAppendRecording, !state.isAppendTranscribing else { return .none }
        state.isAppendRecording = true
        state.recordingStartTime = date.now

        return .merge(
          .run { [sleepManagement, soundEffects] _ in
            await sleepManagement.preventSleep("Voice Recording")
            await recording.startRecording()
            soundEffects.play(.startRecording)
          },
          .run { send in
            let haptic = await UIImpactFeedbackGenerator(style: .medium)
            await haptic.impactOccurred()
            for await level in await recording.observeAudioLevel() {
              await send(.audioLevelUpdated(level))
            }
          }
          .cancellable(id: CancelID.metering)
        )

      case .stopAppendRecording:
        guard state.isAppendRecording else { return .none }
        state.isAppendRecording = false
        state.isAppendTranscribing = true
        soundEffects.play(.stopRecording)

        let model = state.hexSettings.selectedModel
        let language = state.hexSettings.outputLanguage
        let wordRemappings = state.hexSettings.wordRemappings
        let wordRemovals = state.hexSettings.wordRemovals
        let wordRemovalsEnabled = state.hexSettings.wordRemovalsEnabled

        return .merge(
          .cancel(id: CancelID.metering),
          .run { [sleepManagement] send in
            await sleepManagement.allowSleep()
            let haptic = await UIImpactFeedbackGenerator(style: .light)
            await haptic.impactOccurred()

            let audioURL = await recording.stopRecording()

            do {
              var options = DecodingOptions()
              if let language, !language.isEmpty {
                options.language = language
              }
              var text = try await transcription.transcribe(audioURL, model, options) { _ in }

              if wordRemovalsEnabled {
                text = WordRemovalApplier.apply(text, removals: wordRemovals)
              }
              text = WordRemappingApplier.apply(text, remappings: wordRemappings)
              text = text.trimmingCharacters(in: .whitespacesAndNewlines)

              try? FileManager.default.removeItem(at: audioURL)

              await send(.appendTranscriptionResult(text))
            } catch {
              transcriptionLogger.error("Append transcription failed: \(error.localizedDescription)")
              try? FileManager.default.removeItem(at: audioURL)
              await send(.appendTranscriptionFailed)
            }
          }
        )

      case .cancelAppendRecording:
        guard state.isAppendRecording else { return .none }
        state.isAppendRecording = false
        soundEffects.play(.cancel)
        return .merge(
          .cancel(id: CancelID.metering),
          .run { [sleepManagement] _ in
            await sleepManagement.allowSleep()
            _ = await recording.stopRecording()
            let haptic = await UINotificationFeedbackGenerator()
            await haptic.notificationOccurred(.warning)
          }
        )

      case .appendTranscriptionResult(let text):
        state.isAppendTranscribing = false
        if !text.isEmpty {
          state.pendingAppendText = text
          soundEffects.play(.pasteTranscript)
        }
        return .none

      case .appendTranscriptionFailed:
        state.isAppendTranscribing = false
        soundEffects.play(.cancel)
        return .run { _ in
          let haptic = await UINotificationFeedbackGenerator()
          await haptic.notificationOccurred(.error)
        }

      case .updateTranscriptionText(let text):
        state.lastTranscriptionResult = text
        state.pendingAppendText = nil
        // Sync edit to history
        if let id = state.currentTranscriptID {
          state.$transcriptionHistory.withLock { history in
            if let index = history.history.firstIndex(where: { $0.id == id }) {
              history.history[index].text = text
            }
          }
        }
        return .none

      case .updateRefinedText(let text):
        state.refinementStatus = .completed(text)
        // Sync edited refined text to history
        if let id = state.currentTranscriptID {
          state.$transcriptionHistory.withLock { history in
            if let index = history.history.firstIndex(where: { $0.id == id }) {
              history.history[index].refinedText = text
            }
          }
        }
        return .none

      // MARK: - AI Refinement

      case .retriggerRefinement:
        guard let text = state.lastTranscriptionResult,
              state.hexSettings.refinementEnabled,
              refinement.isAvailable() else { return .none }
        state.refinementStatus = .processing
        let instructions = state.hexSettings.refinementInstructions
        let replacements = state.hexSettings.termReplacements
        return .run { send in
          let refined = try await refinement.refine(text, instructions, replacements)
          guard !refined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await send(.refinementFailed)
            return
          }
          await send(.refinementCompleted(refined))
        } catch: { _, send in
          await send(.refinementFailed)
        }
        .cancellable(id: CancelID.refinement)

      case .refinementCompleted(let refined):
        state.refinementStatus = .completed(refined)
        // Update the history entry with refined text
        if let id = state.currentTranscriptID {
          state.$transcriptionHistory.withLock { history in
            if let index = history.history.firstIndex(where: { $0.id == id }) {
              history.history[index].refinedText = refined
            }
          }
        }
        return .none

      case .refinementFailed:
        state.refinementStatus = .failed
        return .none
      }
    }
  }
}

