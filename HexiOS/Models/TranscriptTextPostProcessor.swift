import Foundation
import HexCore

/// Shared post-processing for raw ASR output, so a first attempt and a later
/// retry of the same recording produce identical text.
enum TranscriptTextPostProcessor {
  /// Word removals, remappings, and whitespace trimming.
  static func normalize(_ raw: String, settings: HexSettings) -> String {
    var text = raw
    if settings.wordRemovalsEnabled {
      text = WordRemovalApplier.apply(text, removals: settings.wordRemovals)
    }
    text = WordRemappingApplier.apply(text, remappings: settings.wordRemappings)
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// `normalize` plus the `YYYY-MM-DD` prefix used for primary transcriptions.
  ///
  /// Append transcriptions deliberately skip the prefix — their text is inserted
  /// into an existing transcript that already carries one.
  static func normalizeWithDatePrefix(_ raw: String, settings: HexSettings, date: Date) -> String {
    datePrefixFormatter.string(from: date) + " " + normalize(raw, settings: settings)
  }

  private static let datePrefixFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
}
