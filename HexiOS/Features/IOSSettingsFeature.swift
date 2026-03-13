import ComposableArchitecture
import Dependencies
import Foundation
import HexCore

@Reducer
struct IOSSettingsFeature {
  @ObservableState
  struct State: Equatable {
    @Shared(.hexSettings) var hexSettings: HexSettings
    var modelDownload = ModelDownloadFeature.State()
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case modelDownload(ModelDownloadFeature.Action)
    case task
    case toggleSoundEffects
    case setSoundVolume(Double)
    case toggleHistory
    case setLanguage(String?)
    case setAppleNotesFolderName(String)
    case toggleRefinement
    case setRefinementInstructions(String)
    case addTermReplacement
    case updateTermReplacement(UUID, from: String, to: String)
    case deleteTermReplacement(UUID)
    case resetRefinementDefaults
  }

  var body: some ReducerOf<Self> {
    BindingReducer()

    Scope(state: \.modelDownload, action: \.modelDownload) {
      ModelDownloadFeature()
    }

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .task:
        return .send(.modelDownload(.fetchModels))

      case .toggleSoundEffects:
        state.$hexSettings.withLock { $0.soundEffectsEnabled.toggle() }
        return .none

      case .setSoundVolume(let volume):
        state.$hexSettings.withLock { $0.soundEffectsVolume = volume }
        return .none

      case .toggleHistory:
        state.$hexSettings.withLock { $0.saveTranscriptionHistory.toggle() }
        return .none

      case .setLanguage(let code):
        state.$hexSettings.withLock { $0.outputLanguage = code }
        return .none

      case .setAppleNotesFolderName(let name):
        state.$hexSettings.withLock { $0.appleNotesFolderName = name.isEmpty ? nil : name }
        return .none

      case .toggleRefinement:
        state.$hexSettings.withLock { $0.refinementEnabled.toggle() }
        return .none

      case .setRefinementInstructions(let instructions):
        state.$hexSettings.withLock { $0.refinementInstructions = instructions }
        return .none

      case .addTermReplacement:
        state.$hexSettings.withLock {
          $0.termReplacements.append(TermReplacement(from: "", to: ""))
        }
        return .none

      case .updateTermReplacement(let id, let from, let to):
        state.$hexSettings.withLock { settings in
          if let index = settings.termReplacements.firstIndex(where: { $0.id == id }) {
            settings.termReplacements[index].from = from
            settings.termReplacements[index].to = to
          }
        }
        return .none

      case .deleteTermReplacement(let id):
        state.$hexSettings.withLock { settings in
          settings.termReplacements.removeAll { $0.id == id }
        }
        return .none

      case .resetRefinementDefaults:
        state.$hexSettings.withLock {
          $0.refinementEnabled = true
          $0.refinementInstructions = HexSettings.defaultRefinementInstructions
          $0.termReplacements = []
        }
        return .none

      case .modelDownload:
        return .none
      }
    }
  }
}
