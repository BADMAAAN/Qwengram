import Foundation

public final class QwengramQwenProvider: QwengramAIProvider {
    // Alibaba Cloud Model Studio's documented OpenAI-compatible endpoint.
    public static let defaultEndpoint = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!
    public static let defaultModel = "qwen-plus"

    private let apiKey: String
    private let endpoint: URL
    private let session: URLSession

    public init(apiKey: String, endpoint: URL = QwengramQwenProvider.defaultEndpoint, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.session = session
    }

    public func generateText(model: String, messages: [QwengramAIMessage], completion: @escaping (Result<String, QwengramAIError>) -> Void) {
        guard !apiKey.isEmpty, !model.isEmpty, !messages.isEmpty else {
            completion(.failure(.invalidRequest))
            return
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(Request(model: model, messages: messages))
        } catch {
            completion(.failure(.invalidRequest))
            return
        }
        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(.network(error.localizedDescription)))
                return
            }
            guard let response = response as? HTTPURLResponse else {
                completion(.failure(.network("Missing HTTP response")))
                return
            }
            guard (200 ... 299).contains(response.statusCode) else {
                completion(.failure(.httpStatus(response.statusCode)))
                return
            }
            guard let data else {
                completion(.failure(.emptyResponse))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(Response.self, from: data)
                guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
                    completion(.failure(.emptyResponse))
                    return
                }
                completion(.success(text))
            } catch {
                completion(.failure(.decoding))
            }
        }.resume()
    }

    private struct Request: Encodable {
        let model: String
        let messages: [QwengramAIMessage]
    }

    private struct Response: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message
        }
        let choices: [Choice]
    }
}
