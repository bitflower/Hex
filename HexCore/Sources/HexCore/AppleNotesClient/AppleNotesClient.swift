import Dependencies
import DependenciesMacros

/// Client for saving transcriptions to Apple Notes.
///
/// On macOS, this uses AppleScript to create notes directly in Apple Notes.
/// On iOS, this copies the text to the clipboard and opens the Notes app.
///
/// ## Usage
///
/// ```swift
/// @Dependency(\.appleNotes) var appleNotes
///
/// try await appleNotes.saveNote("My transcription", "Stream of Thought")
/// ```
@DependencyClient
public struct AppleNotesClient: Sendable {
  /// Save a note to Apple Notes.
  ///
  /// - Parameters:
  ///   - text: The transcription text to save as the note body.
  ///   - folderName: The target folder in Apple Notes. If `nil`, saves to the default folder.
  public var saveNote: @Sendable (_ text: String, _ folderName: String?) async throws -> Void
}

extension DependencyValues {
  /// Access the Apple Notes client dependency.
  public var appleNotes: AppleNotesClient {
    get { self[AppleNotesClient.self] }
    set { self[AppleNotesClient.self] = newValue }
  }
}
