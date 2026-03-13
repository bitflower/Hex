import Foundation

public struct TermReplacement: Codable, Equatable, Identifiable, Sendable {
	public var id: UUID
	public var from: String
	public var to: String

	public init(
		id: UUID = UUID(),
		from: String,
		to: String
	) {
		self.id = id
		self.from = from
		self.to = to
	}
}
