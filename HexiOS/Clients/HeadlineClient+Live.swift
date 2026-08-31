import Dependencies
import Foundation
import HexCore
import os

private let headlineLogger = Logger(subsystem: "com.kitlangton.Hex", category: "headline")

#if canImport(FoundationModels)
import FoundationModels

extension HeadlineClient: DependencyKey {
    static let liveValue: HeadlineClient = {
        if #available(iOS 26.0, *) {
            return HeadlineClient(
                isAvailable: {
                    let available = SystemLanguageModel.default.isAvailable
                    headlineLogger.info("Headline isAvailable: \(available)")
                    return available
                },
                generate: { transcript in
                    let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Too short to meaningfully summarize; skip the model call.
                    guard trimmed.count >= 12 else { return nil }

                    let systemInstructions = """
                    Formuliere aus der folgenden Sprachtranskription eine sehr kurze, prägnante Überschrift (maximal 8 Wörter) in derselben Sprache wie die Transkription.

                    Gib ausschließlich die Überschrift zurück. Keine Anführungszeichen, kein Satzzeichen am Ende, keine Erklärungen, kein Präfix wie "Überschrift:".
                    """

                    let session = LanguageModelSession(instructions: systemInstructions)

                    let prompt = """
                    Transkription:
                    \(trimmed)
                    """

                    headlineLogger.info("Headline prompt length: \(prompt.count)")
                    let response = try await session.respond(to: prompt)
                    let headline = response.content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'.“”"))
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    headlineLogger.info("Headline response length: \(headline.count)")
                    return headline.isEmpty ? nil : headline
                }
            )
        } else {
            return HeadlineClient(
                isAvailable: { false },
                generate: { _ in nil }
            )
        }
    }()
}
#else
extension HeadlineClient: DependencyKey {
    static let liveValue = HeadlineClient(
        isAvailable: { false },
        generate: { _ in nil }
    )
}
#endif
