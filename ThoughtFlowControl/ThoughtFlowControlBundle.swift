import SwiftUI
import WidgetKit

@main
struct ThoughtFlowControlBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOSApplicationExtension 18.0, *) {
            RecordingControlWidget()
        }
    }
}
