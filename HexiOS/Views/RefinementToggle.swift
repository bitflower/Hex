import SwiftUI

enum RefinementDisplayMode: Equatable {
    case original
    case refined
}

struct RefinementToggle: View {
    let isProcessing: Bool
    let isAvailable: Bool
    @Binding var displayMode: RefinementDisplayMode

    var body: some View {
        HStack(spacing: 12) {
            Picker("", selection: $displayMode) {
                Text("Original").tag(RefinementDisplayMode.original)
                Text("Refined").tag(RefinementDisplayMode.refined)
            }
            .pickerStyle(.segmented)
            .disabled(!isAvailable)

            if isProcessing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refining...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
