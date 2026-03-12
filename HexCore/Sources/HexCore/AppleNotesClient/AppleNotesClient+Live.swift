#if os(macOS)
import Dependencies
import Foundation

private let notesLogger = HexLog.notes

extension AppleNotesClient: DependencyKey {
  public static var liveValue: Self {
    Self(
      saveNote: { text, folderName in
        try await saveNoteWithAppleScript(text: text, folderName: folderName)
      }
    )
  }
}

private func saveNoteWithAppleScript(text: String, folderName: String?) async throws {
  let escapedText = text
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
    .replacingOccurrences(of: "\n", with: "\\n")
    .replacingOccurrences(of: "\r", with: "\\r")
    .replacingOccurrences(of: "\t", with: "\\t")

  let folderClause: String
  if let folderName, !folderName.isEmpty {
    let escapedFolder = folderName
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    folderClause = """
      set targetFolder to null
      try
        set targetFolder to folder "\(escapedFolder)" of default account
      on error
        make new folder at default account with properties {name:"\(escapedFolder)"}
        set targetFolder to folder "\(escapedFolder)" of default account
      end try
      make new note at targetFolder with properties {body:"\(escapedText)"}
    """
  } else {
    folderClause = """
      make new note with properties {body:"\(escapedText)"}
    """
  }

  let script = """
  tell application "Notes"
    \(folderClause)
  end tell
  """

  try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
    DispatchQueue.global(qos: .userInitiated).async {
      var error: NSDictionary?
      let appleScript = NSAppleScript(source: script)
      appleScript?.executeAndReturnError(&error)

      if let error {
        let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
        notesLogger.error("Failed to save note to Apple Notes: \(message)")
        continuation.resume(throwing: AppleNotesError.scriptFailed(message))
      } else {
        notesLogger.info("Saved note to Apple Notes")
        continuation.resume()
      }
    }
  }
}

public enum AppleNotesError: Error, LocalizedError {
  case scriptFailed(String)

  public var errorDescription: String? {
    switch self {
    case .scriptFailed(let message):
      return "Failed to save to Apple Notes: \(message)"
    }
  }
}

#elseif os(iOS)
import Dependencies
import UIKit

extension AppleNotesClient: DependencyKey {
  public static var liveValue: Self {
    Self(
      saveNote: { text, _ in
        await MainActor.run {
          UIPasteboard.general.string = text
        }
        if let url = URL(string: "mobilenotes://") {
          await MainActor.run {
            UIApplication.shared.open(url)
          }
        }
      }
    )
  }
}
#endif
