import Dependencies
import Foundation
import HexCore
import os

private let refinementLogger = Logger(subsystem: "com.kitlangton.Hex", category: "refinement")

#if canImport(FoundationModels)
import FoundationModels

extension RefinementClient: DependencyKey {
    static let liveValue: RefinementClient = {
        if #available(iOS 26.0, *) {
            return RefinementClient(
                isAvailable: {
                    let available = SystemLanguageModel.default.isAvailable
                    refinementLogger.info("Refinement isAvailable: \(available)")
                    return available
                },
                refine: { rawText, instructions, replacements in
                    let replacementBlock: String
                    if replacements.isEmpty {
                        replacementBlock = ""
                    } else {
                        let pairs = replacements
                            .map { "\"\($0.from)\" → \"\($0.to)\"" }
                            .joined(separator: "\n")
                        replacementBlock = "\nApply these term replacements:\n\(pairs)\n"
                    }

                    let systemInstructions = """
                    \(instructions)

                    Output ONLY the refined text. No explanations, no meta-text.
                    \(replacementBlock)
                    """

                    let session = LanguageModelSession(instructions: systemInstructions)

                    let prompt = """
                    Transcription to refine:
                    \(rawText)
                    """

                    refinementLogger.info("Refinement prompt length: \(prompt.count), instructions length: \(systemInstructions.count)")
                    let response = try await session.respond(to: prompt)
                    let result = response.content
                    refinementLogger.info("Refinement response length: \(result.count)")

                    return result.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            )
        } else {
            return RefinementClient(
                isAvailable: { false },
                refine: { rawText, _, _ in rawText }
            )
        }
    }()
}
#else
extension RefinementClient: DependencyKey {
    static let liveValue = RefinementClient(
        isAvailable: { false },
        refine: { rawText, _, _ in rawText }
    )
}
#endif
