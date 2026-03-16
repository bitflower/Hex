import AppIntents
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 18.0, *)
struct RecordingControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.kitlangton.Hex.RecordControl") {
            ControlWidgetButton(action: StartRecordingIntent()) {
                Label("Record Thoughts", systemImage: "mic.fill")
            }
        }
        .displayName("Record Thoughts")
        .description("Start a voice recording.")
    }
}
