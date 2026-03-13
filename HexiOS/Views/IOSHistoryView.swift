import ComposableArchitecture
import HexCore
import SwiftUI

struct IOSHistoryView: View {
  let store: StoreOf<HistoryFeature>
  @State private var showingDeleteConfirmation = false
  @Shared(.hexSettings) var hexSettings: HexSettings

  var body: some View {
    NavigationStack {
      Group {
        if !hexSettings.saveTranscriptionHistory {
          ContentUnavailableView {
            Label("History Disabled", systemImage: "clock.arrow.circlepath")
          } description: {
            Text("Transcription history is currently disabled. Enable it in Settings.")
          }
        } else if store.transcriptionHistory.history.isEmpty {
          ContentUnavailableView {
            Label("No Transcriptions", systemImage: "text.bubble")
          } description: {
            Text("Your transcription history will appear here.")
          }
        } else {
          List {
            ForEach(store.transcriptionHistory.history) { transcript in
              IOSTranscriptRow(
                transcript: transcript,
                isPlaying: store.playingTranscriptID == transcript.id,
                onTap: { store.send(.openTranscript(text: transcript.text, refinedText: transcript.refinedText)) },
                onPlay: { store.send(.playTranscript(transcript.id)) },
                onCopy: { store.send(.copyToClipboard(transcript.refinedText ?? transcript.text)) },
                onSaveToNotes: { store.send(.saveToAppleNotes(transcript.refinedText ?? transcript.text, transcriptID: transcript.id)) },
                onAppendToNote: { store.send(.appendToAppleNote(transcript.refinedText ?? transcript.text, transcriptID: transcript.id)) }
              )
              .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                  store.send(.deleteTranscript(transcript.id))
                } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
            }
          }
          .listStyle(.plain)
        }
      }
      .navigationTitle("History")
      .toolbar {
        if !store.transcriptionHistory.history.isEmpty {
          Button(role: .destructive) {
            showingDeleteConfirmation = true
          } label: {
            Label("Delete All", systemImage: "trash")
          }
        }
      }
      .alert("Delete All Transcripts", isPresented: $showingDeleteConfirmation) {
        Button("Delete All", role: .destructive) {
          store.send(.confirmDeleteAll)
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Are you sure you want to delete all transcripts? This action cannot be undone.")
      }
    }
  }
}

struct IOSTranscriptRow: View {
  let transcript: Transcript
  let isPlaying: Bool
  let onTap: () -> Void
  let onPlay: () -> Void
  let onCopy: () -> Void
  let onSaveToNotes: () -> Void
  let onAppendToNote: () -> Void
  @State private var showCopied = false
  @State private var showSavedToNotes = false
  @State private var showAppended = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      VStack(alignment: .leading, spacing: 8) {
        Text(transcript.refinedText ?? transcript.text)
          .font(.body)
          .lineLimit(4)

        HStack(spacing: 6) {
          Image(systemName: "clock")
          Text(transcript.timestamp.relativeFormatted())
          Text("·")
          Text(transcript.timestamp.formatted(date: .omitted, time: .shortened))
          Text("·")
          Text(String(format: "%.1fs", transcript.duration))
          if transcript.refinedText != nil {
            Image(systemName: "sparkles")
              .font(.caption2)
              .foregroundStyle(.purple)
          }
          if transcript.savedToNotes == true {
            Image(systemName: "note.text")
              .font(.caption2)
              .foregroundStyle(.orange)
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .contentShape(Rectangle())
      .onTapGesture { onTap() }

      HStack(spacing: 16) {
        historyActionButton(
          label: showCopied ? "Copied" : "Copy",
          icon: showCopied ? "checkmark" : "doc.on.doc",
          tint: showCopied ? .green : .primary
        ) {
          onCopy()
          withAnimation { showCopied = true }
          Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { showCopied = false }
          }
        }

        historyActionButton(
          label: showSavedToNotes ? "Saved" : "New Note",
          icon: showSavedToNotes ? "checkmark" : "note.text",
          tint: showSavedToNotes ? .green : .primary
        ) {
          onSaveToNotes()
          withAnimation { showSavedToNotes = true }
          Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { showSavedToNotes = false }
          }
        }

        historyActionButton(
          label: showAppended ? "Appended" : "Append",
          icon: showAppended ? "checkmark" : "note.text.badge.plus",
          tint: showAppended ? .green : .primary
        ) {
          onAppendToNote()
          withAnimation { showAppended = true }
          Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { showAppended = false }
          }
        }

        historyActionButton(
          label: isPlaying ? "Stop" : "Play",
          icon: isPlaying ? "stop.fill" : "play.fill",
          tint: isPlaying ? .blue : .primary
        ) {
          onPlay()
        }
      }
    }
    .padding(.vertical, 4)
  }

  private func historyActionButton(label: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
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
    .buttonStyle(.borderless)
    .foregroundStyle(tint)
  }
}
