import AppIntents
import Foundation

/// Thread-safe flag set by the intent before the app opens.
/// The app polls this on scene activation to start recording.
enum RecordingIntentFlag {
    private static let key = "pendingRecordingIntent"
    static func set() {
        UserDefaults.standard.set(true, forKey: key)
    }
    static func consumeIfSet() -> Bool {
        guard UserDefaults.standard.bool(forKey: key) else { return false }
        UserDefaults.standard.set(false, forKey: key)
        return true
    }
}

/// App Intent that opens ThoughtFlow and immediately starts recording.
/// Available via Siri, Action Button, Spotlight, Control Center, and Lock Screen.
///
/// This file must have target membership in BOTH the main app and the widget extension.
@available(iOS 16.0, *)
struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Record with ThoughtFlow"
    static let description: IntentDescription = "Opens ThoughtFlow and starts a voice recording immediately."
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        RecordingIntentFlag.set()
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
