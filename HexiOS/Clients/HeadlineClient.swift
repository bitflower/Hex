import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation
import HexCore

/// Derives a short headline from a transcript, so users don't have to add one
/// by hand after each recording. Backed by Apple's on-device Foundation
/// Models framework where available; unavailable/failed generation simply
/// yields no headline, and callers fall back to the plain date-prefixed text.
@DependencyClient
struct HeadlineClient: Sendable {
    var isAvailable: @Sendable () -> Bool = { false }
    var generate: @Sendable (_ transcript: String) async throws -> String? = { _ in nil }
}

extension HeadlineClient: TestDependencyKey {
    static let testValue = HeadlineClient()
    static let previewValue = HeadlineClient(
        isAvailable: { true },
        generate: { _ in "Preview Headline" }
    )
}

extension DependencyValues {
    var headline: HeadlineClient {
        get { self[HeadlineClient.self] }
        set { self[HeadlineClient.self] = newValue }
    }
}
