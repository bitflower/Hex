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
  /// When a `headline` is supplied, it's placed right after the date, and the
  /// transcript follows on its own paragraph:
  ///
  /// ```
  /// 2026-08-31 Team sync on deployment plan
  ///
  /// We agreed to move the endpoint to the new cluster...
  /// ```
  ///
  /// Without a headline (e.g. generation was unavailable or failed), the
  /// transcript simply follows the date on the same line, unchanged from
  /// prior behavior.
  ///
  /// Append transcriptions deliberately skip the prefix — their text is inserted
  /// into an existing transcript that already carries one.
  static func normalizeWithDatePrefix(
    _ raw: String,
    settings: HexSettings,
    date: Date,
    headline: String? = nil
  ) -> String {
    let prefix = datePrefixFormatter.string(from: date)
    let body = normalize(raw, settings: settings)
    guard let headline, !headline.isEmpty else {
      return prefix + " " + body
    }
    return prefix + " " + headline + "\n\n" + body
  }

  private static let datePrefixFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
}
