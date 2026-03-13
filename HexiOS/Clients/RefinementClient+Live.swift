import Dependencies
import Foundation
import HexCore

#if canImport(FoundationModels)
import FoundationModels

extension RefinementClient: DependencyKey {
    static let liveValue: RefinementClient = {
        if #available(iOS 26.0, *) {
            return RefinementClient(
                isAvailable: {
                    SystemLanguageModel.default.isAvailable
                },
                refine: { rawText, instructions, replacements in
                    let session = LanguageModelSession()

                    let replacementBlock: String
                    if replacements.isEmpty {
                        replacementBlock = ""
                    } else {
                        let pairs = replacements
                            .map { "\"\($0.from)\" → \"\($0.to)\"" }
                            .joined(separator: "\n")
                        replacementBlock = "\nApply these term replacements:\n\(pairs)\n"
                    }

                    let prompt = """
                    \(instructions)
                    \(replacementBlock)
                    Transcription to refine:
                    \"\"\"
                    \(rawText)
                    \"\"\"

                    Return only the refined text.
                    """

                    let response = try await session.respond(to: prompt)
                    return response.content
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
