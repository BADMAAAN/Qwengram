import Foundation

public struct QwengramAIMessage: Codable, Equatable {
    public enum Role: String, Codable {
        case system
        case user
        case assistant
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}
