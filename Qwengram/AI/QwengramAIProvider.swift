import Foundation

public protocol QwengramAIProvider {
    func generateText(
        model: String,
        messages: [QwengramAIMessage],
        completion: @escaping (Result<String, QwengramAIError>) -> Void
    )
}
