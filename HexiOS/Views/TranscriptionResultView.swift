import ComposableArchitecture
import SwiftUI

struct TranscriptionResultView: View {
  let store: StoreOf<IOSTranscriptionFeature>
  @State private var showCopied = false
  @State private var showSavedToNotes = false
  @State private var showAppended = false
  @State private var editableText: String = ""
  @State private var selection: TextSelection?

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
        TextEditor(text: $editableText, selection: $selection)
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
              let insertionIndex: String.Index
              if let selection,
                 case .selection(let range) = selection.indices {
                insertionIndex = range.lowerBound
              } else {
                insertionIndex = editableText.endIndex
              }

              var prefix = ""
              if insertionIndex > editableText.startIndex {
                let charBefore = editableText[editableText.index(before: insertionIndex)]
                if !charBefore.isWhitespace && !newText.hasPrefix(" ") {
                  prefix = " "
                }
              }

              editableText.insert(contentsOf: prefix + newText, at: insertionIndex)
              store.send(.updateTranscriptionText(editableText))
            }
          }
      }

      Divider()

      // Actions
      HStack(spacing: 8) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            actionButton(
              label: showCopied ? "Copied" : "Copy",
              icon: showCopied ? "checkmark" : "doc.on.doc",
              tint: showCopied ? .green : .primary
            ) {
              store.send(.copyResult)
              withAnimation { showCopied = true }
              Task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation { showCopied = false }
              }
            }

            if let text = store.lastTranscriptionResult, !text.isEmpty {
              ShareLink(item: text) {
                actionLabel(label: "Share", icon: "square.and.arrow.up")
                  .foregroundStyle(.primary)
              }
              .buttonStyle(.plain)

              actionButton(
                label: showSavedToNotes ? "Saved" : "New Note",
                icon: showSavedToNotes ? "checkmark" : "note.text",
                tint: showSavedToNotes ? .green : .primary
              ) {
                store.send(.saveToAppleNotes)
                withAnimation { showSavedToNotes = true }
                Task {
                  try? await Task.sleep(for: .seconds(1.5))
                  withAnimation { showSavedToNotes = false }
                }
              }

              actionButton(
                label: showAppended ? "Appended" : "Append",
                icon: showAppended ? "checkmark" : "note.text.badge.plus",
                tint: showAppended ? .green : .primary
              ) {
                store.send(.appendToAppleNote)
                withAnimation { showAppended = true }
                Task {
                  try? await Task.sleep(for: .seconds(1.5))
                  withAnimation { showAppended = false }
                }
              }
            }
          }
          .padding(.leading)
        }

        if store.transcriptionError == nil {
          appendRecordButton
            .padding(.trailing)
        }
      }
      .padding(.vertical, 12)
    }
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(radius: 20, y: 10)
    .padding()
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  private func actionButton(label: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      actionLabel(label: label, icon: icon)
    }
    .tint(tint)
    .buttonStyle(.plain)
  }

  private func actionLabel(label: String, icon: String) -> some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.body)
        .frame(height: 20)
      Text(label)
        .font(.caption2)
        .lineLimit(1)
    }
    .frame(minWidth: 48)
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
