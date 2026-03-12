import ComposableArchitecture
import SwiftUI

struct TranscriptionResultView: View {
  let store: StoreOf<IOSTranscriptionFeature>
  @State private var showCopied = false
  @State private var showSavedToNotes = false
  @State private var showAppended = false
  @State private var editableText: String = ""

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("Transcription")
          .font(.headline)
        Spacer()
        Button { store.send(.clearResult) } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
            .font(.title3)
        }
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
      }

      Divider()

      // Actions
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          actionButton(
            label: showCopied ? "Copied" : "Copy",
            icon: showCopied ? "checkmark" : "doc.on.doc",
            tint: showCopied ? .green : .accentColor
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
            }
            .tint(.accentColor)

            actionButton(
              label: showSavedToNotes ? "Saved" : "New Note",
              icon: showSavedToNotes ? "checkmark" : "note.text",
              tint: showSavedToNotes ? .green : .accentColor
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
              tint: showAppended ? .green : .accentColor
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
        .padding(.horizontal)
        .padding(.vertical, 12)
      }
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
    .buttonStyle(.bordered)
  }

  private func actionLabel(label: String, icon: String) -> some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.body)
      Text(label)
        .font(.caption2)
    }
    .frame(minWidth: 56)
  }
}
