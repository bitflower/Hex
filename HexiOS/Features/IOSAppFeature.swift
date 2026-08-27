import ComposableArchitecture
import Foundation
import HexCore

@Reducer
struct IOSAppFeature {
  enum ActiveTab: Equatable {
    case record
    case history
    case settings
  }

  @ObservableState
  struct State: Equatable {
    var transcription = IOSTranscriptionFeature.State()
    var settings = IOSSettingsFeature.State()
    var history = HistoryFeature.State()
    var activeTab: ActiveTab = .record
    var tabBeforeTranscriptOpen: ActiveTab?
    var microphonePermission: PermissionStatus = .notDetermined
    /// The stranded-recording sweep must run at most once per process — a
    /// recording that is merely in flight also sits in the temp directory, and
    /// SwiftUI may re-fire the root `.task`.
    var didSweepStrandedRecordings = false
  }

  enum Action {
    case transcription(IOSTranscriptionFeature.Action)
    case settings(IOSSettingsFeature.Action)
    case history(HistoryFeature.Action)
    case task
    case tabChanged(ActiveTab)
    case checkPermissions
    case microphoneStatusUpdated(PermissionStatus)
    case requestMicrophone
    case microphoneRequestResult(Bool)
    case startRecordingFromIntent
  }

  @Dependency(\.permissions) var permissions

  var body: some ReducerOf<Self> {
    Scope(state: \.transcription, action: \.transcription) {
      IOSTranscriptionFeature()
    }
    Scope(state: \.settings, action: \.settings) {
      IOSSettingsFeature()
    }
    Scope(state: \.history, action: \.history) {
      HistoryFeature()
    }

    Reduce { state, action in
      switch action {
      case .task:
        let shouldSweep = !state.didSweepStrandedRecordings
        state.didSweepStrandedRecordings = true
        let saveHistory = state.transcription.hexSettings.saveTranscriptionHistory
        let transcriptionHistory = state.transcription.$transcriptionHistory

        return .merge(
          .run { send in
            await send(.checkPermissions)
          },
          .run { _ in
            // Adopt recordings a crash or force-quit stranded in the temp
            // directory, before iOS purges them.
            guard shouldSweep else { return }
            guard saveHistory else {
              OrphanedRecordingRecovery.discardStrandedRecordings()
              return
            }
            let recovered = OrphanedRecordingRecovery.recoverStrandedRecordings()
            guard !recovered.isEmpty else { return }
            transcriptionHistory.withLock { history in
              history.history.insert(contentsOf: recovered, at: 0)
            }
          },
          .run { send in
            // Listen for recording intent from lock screen / Siri / Action Button
            for await _ in NotificationCenter.default.notifications(named: .startRecordingFromIntent) {
              await send(.startRecordingFromIntent)
            }
          }
        )

      case .tabChanged(let tab):
        state.activeTab = tab
        return .none

      case .checkPermissions:
        return .run { send in
          let status = await permissions.microphoneStatus()
          await send(.microphoneStatusUpdated(status))
        }

      case .microphoneStatusUpdated(let status):
        state.microphonePermission = status
        return .none

      case .requestMicrophone:
        return .run { send in
          let granted = await permissions.requestMicrophone()
          await send(.microphoneRequestResult(granted))
        }

      case .microphoneRequestResult(let granted):
        state.microphonePermission = granted ? .granted : .denied
        return .none

      case .startRecordingFromIntent:
        state.activeTab = .record
        guard state.microphonePermission == .granted,
              state.transcription.modelBootstrapState.isModelReady,
              !state.transcription.isRecording,
              !state.transcription.isTranscribing else { return .none }
        return .send(.transcription(.startRecording))

      case .history(.openTranscript(let text, let refinedText)):
        state.tabBeforeTranscriptOpen = state.activeTab
        return .send(.transcription(.openTranscriptWithRefinement(text, refinedText)))

      case .transcription(.clearResult):
        state.tabBeforeTranscriptOpen = nil
        return .none

      case .transcription, .settings, .history:
        return .none
      }
    }
  }
}
