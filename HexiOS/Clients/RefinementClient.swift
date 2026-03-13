import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation
import HexCore

@DependencyClient
struct RefinementClient: Sendable {
    var isAvailable: @Sendable () -> Bool = { false }
    var refine: @Sendable (
        _ rawText: String,
        _ instructions: String,
        _ replacements: [TermReplacement]
    ) async throws -> String = { _, _, _ in "" }
}

extension RefinementClient: TestDependencyKey {
    static let testValue = RefinementClient()
    static let previewValue = RefinementClient(
        isAvailable: { true },
        refine: { rawText, _, _ in rawText }
    )
}

extension DependencyValues {
    var refinement: RefinementClient {
        get { self[RefinementClient.self] }
        set { self[RefinementClient.self] = newValue }
    }
}
