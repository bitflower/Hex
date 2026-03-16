import AppIntents
import Foundation

/// App Intent that opens ThoughtFlow and immediately starts recording.
/// Available via Siri ("Record with ThoughtFlow"), Action Button, Spotlight, and Lock Screen.
@available(iOS 16.0, *)
struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Record with ThoughtFlow"
    static let description: IntentDescription = "Opens ThoughtFlow and starts a voice recording immediately."
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .startRecordingFromIntent, object: nil)
        return .result()
    }
}

/// Registers the intent as an App Shortcut so it appears in Spotlight, Siri, and Action Button config.
@available(iOS 16.0, *)
struct ThoughtFlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Record with \(.applicationName)",
                "Start recording in \(.applicationName)",
                "New recording in \(.applicationName)"
            ],
            shortTitle: "Record",
            systemImageName: "mic.fill"
        )
    }
}

extension Notification.Name {
    static let startRecordingFromIntent = Notification.Name("startRecordingFromIntent")
}
