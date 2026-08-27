import CoreTransferable
import HexCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Share presentation helpers

// `resolvedAudioURL()` lives in HexCore alongside `RecordingStore`.

extension Transcript {
  /// Short text label suitable for `SharePreview` titles.
  var sharePreviewTitle: String {
    let base = (refinedText ?? text).trimmingCharacters(in: .whitespacesAndNewlines)
    if base.isEmpty {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .short
      return "ThoughtFlow \(formatter.string(from: timestamp))"
    }
    let prefix = base.prefix(60)
    return String(prefix) + (base.count > 60 ? "…" : "")
  }

  /// Human-friendly filename base (without extension) for the exported audio,
  /// e.g. `ThoughtFlow 2026-04-22 14-14`.
  var audioExportFilenameBase: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH-mm"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return "ThoughtFlow \(formatter.string(from: timestamp))"
  }
}

// MARK: - Transferable audio with a pretty filename

/// Wraps a `.wav` URL and hands the share sheet a copy with a human-friendly
/// filename. Copy happens only at export time (not at view construction), so
/// scrolling the history list does not duplicate files.
struct TranscriptAudioExport: Transferable {
  let sourceURL: URL
  let suggestedNameBase: String

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .wav) { export in
      let fm = FileManager.default
      let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
      let dst = dir.appendingPathComponent("\(export.suggestedNameBase).wav")
      if fm.fileExists(atPath: dst.path) {
        try fm.removeItem(at: dst)
      }
      try fm.copyItem(at: export.sourceURL, to: dst)
      return SentTransferredFile(dst)
    }
  }
}

// MARK: - Share menu

/// A reusable menu that lets the user share a transcript's text, audio, or both.
///
/// Audio-bearing items are disabled when the audio file cannot be located.
/// Text items are disabled when the text is empty.
struct TranscriptShareMenu<Trigger: View>: View {
  let text: String
  let audioURL: URL?
  let previewTitle: String
  let audioFilenameBase: String
  @ViewBuilder var trigger: () -> Trigger

  @State private var shareBothPayload: ShareBothPayload?

  private var hasText: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    Menu {
      if hasText {
        ShareLink(item: text, preview: SharePreview(previewTitle)) {
          Label("Share Text", systemImage: "doc.text")
        }
      } else {
        Button {} label: { Label("Share Text", systemImage: "doc.text") }
          .disabled(true)
      }

      if let audioURL {
        ShareLink(
          item: TranscriptAudioExport(sourceURL: audioURL, suggestedNameBase: audioFilenameBase),
          preview: SharePreview(previewTitle, image: Image(systemName: "waveform"))
        ) {
          Label("Share Audio", systemImage: "waveform")
        }
      } else {
        Button {} label: { Label("Share Audio", systemImage: "waveform") }
          .disabled(true)
      }

      if hasText, let audioURL {
        Button {
          shareBothPayload = ShareBothPayload(
            text: text,
            sourceAudioURL: audioURL,
            filenameBase: audioFilenameBase
          )
        } label: {
          Label("Share Both", systemImage: "square.and.arrow.up.on.square")
        }
      } else {
        Button {} label: { Label("Share Both", systemImage: "square.and.arrow.up.on.square") }
          .disabled(true)
      }
    } label: {
      trigger()
    }
    .sheet(item: $shareBothPayload) { payload in
      ActivityPresenter(items: payload.activityItems)
        .ignoresSafeArea()
    }
  }
}

// MARK: - Share Both plumbing

private struct ShareBothPayload: Identifiable {
  let id = UUID()
  let text: String
  let sourceAudioURL: URL
  let filenameBase: String

  /// Items handed to `UIActivityViewController`. The audio is copied to a temp
  /// file with a pretty name so destinations like Files / Mail show it with
  /// `ThoughtFlow YYYY-MM-DD HH-mm.wav` instead of `1745347200.wav`.
  var activityItems: [Any] {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    do {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
      let dst = dir.appendingPathComponent("\(filenameBase).wav")
      try fm.copyItem(at: sourceAudioURL, to: dst)
      return [text, dst]
    } catch {
      return [text, sourceAudioURL]
    }
  }
}

private struct ActivityPresenter: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
