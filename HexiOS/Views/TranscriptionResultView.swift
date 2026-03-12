import ComposableArchitecture
import SwiftUI

struct TranscriptionResultView: View {
  let store: StoreOf<IOSTranscriptionFeature>
  @State private var showCopied = false
  @State private var editableText: String = ""

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("Transcription")
          .font(.headline)

        if store.isAppendRecording {
          HStack(spacing: 4) {
            Circle()
              .fill(Color.red)
              .frame(width: 8, height: 8)
            Text("Recording")
              .font(.caption)
              .foregroundStyle(.red)
          }
          .transition(.opacity)
        }

        Spacer()

        Button { store.send(.clearResult) } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
            .font(.title3)
        }
        .disabled(store.isAppendRecording || store.isAppendTranscribing)
        .opacity(store.isAppendRecording || store.isAppendTranscribing ? 0.4 : 1)
      }
      .padding()

      Divider()

      // Content
      if let error = store.transcriptionError {
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
            .foregroundStyle(.orange)
          Text(error)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
      } else {
        TextEditor(text: $editableText)
          .font(.body)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .frame(minHeight: 100)
          .onAppear {
            editableText = store.lastTranscriptionResult ?? ""
          }
          .onChange(of: store.lastTranscriptionResult) { _, newValue in
            editableText = newValue ?? ""
          }
          .onChange(of: store.pendingAppendText) { _, newValue in
            if let newText = newValue, !newText.isEmpty {
              if !editableText.isEmpty && !editableText.hasSuffix(" ") && !newText.hasPrefix(" ") {
                editableText += " "
              }
              editableText += newText
              store.send(.updateTranscriptionText(editableText))
            }
          }
      }

      Divider()

      // Actions
      HStack(spacing: 16) {
        Button {
          store.send(.copyResult)
          withAnimation { showCopied = true }
          Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { showCopied = false }
          }
        } label: {
          Label(showCopied ? "Copied" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .tint(showCopied ? .green : .accentColor)

        if let text = store.lastTranscriptionResult, !text.isEmpty {
          ShareLink(item: text) {
            Label("Share", systemImage: "square.and.arrow.up")
          }
          .buttonStyle(.bordered)
        }

        Spacer()

        if store.transcriptionError == nil {
          appendRecordButton
        }
      }
      .padding()
    }
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(radius: 20, y: 10)
    .padding()
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  @ViewBuilder
  private var appendRecordButton: some View {
    if store.isAppendTranscribing {
      ProgressView()
        .frame(width: 36, height: 36)
    } else {
      Button {
        if store.isAppendRecording {
          store.send(.stopAppendRecording)
        } else {
          store.send(.startAppendRecording)
        }
      } label: {
        Image(systemName: store.isAppendRecording ? "stop.fill" : "mic.fill")
          .font(.system(size: 14))
          .foregroundStyle(.white)
          .frame(width: 36, height: 36)
          .background(store.isAppendRecording ? Color.red : Color.accentColor)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(store.isAppendRecording ? "Stop recording" : "Record more")
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.isAppendRecording)
    }
  }
}
