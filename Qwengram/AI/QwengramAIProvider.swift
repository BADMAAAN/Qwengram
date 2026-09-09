import Foundation

public protocol QwengramAIProvider {
    func generateText(
        model: String,
        messages: [QwengramAIMessage],
        completion: @escaping (Result<String, QwengramAIError>) -> Void
    )
}

public protocol QwengramAIStreamingTask {
    func cancel()
}

public protocol QwengramAIStreamingProvider {
    @discardableResult
    func streamText(
        model: String,
        messages: [QwengramAIMessage],
        onUpdate: @escaping (String) -> Void,
        completion: @escaping (Result<Void, QwengramAIError>) -> Void
    ) -> QwengramAIStreamingTask?
}
