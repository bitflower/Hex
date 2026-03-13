import ComposableArchitecture
import SwiftUI

struct MainTabView: View {
  @Bindable var store: StoreOf<IOSAppFeature>

  var body: some View {
    ZStack {
      TabView(selection: $store.activeTab.sending(\.tabChanged)) {
        RecordingView(
          store: store.scope(state: \.transcription, action: \.transcription),
          micPermission: store.microphonePermission,
          onRequestMic: { store.send(.requestMicrophone) }
        )
        .tabItem {
          Label("Record", systemImage: "mic.fill")
        }
        .tag(IOSAppFeature.ActiveTab.record)

        IOSHistoryView(store: store.scope(state: \.history, action: \.history))
          .tabItem {
            Label("History", systemImage: "clock.arrow.circlepath")
          }
          .tag(IOSAppFeature.ActiveTab.history)

        IOSSettingsView(store: store.scope(state: \.settings, action: \.settings))
          .tabItem {
            Label("Settings", systemImage: "gear")
          }
          .tag(IOSAppFeature.ActiveTab.settings)
      }

      // Show transcription result as overlay when opened from history
      if store.tabBeforeTranscriptOpen != nil,
         store.transcription.lastTranscriptionResult != nil || store.transcription.transcriptionError != nil {
        TranscriptionResultView(store: store.scope(state: \.transcription, action: \.transcription))
      }
    }
    .task { store.send(.task) }
  }
}
