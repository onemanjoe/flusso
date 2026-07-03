import Foundation

public enum OllamaError: Error, Equatable {
    case unreachable, timeout, badResponse
}

public final class OllamaClient {
    private let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    private struct TagsResponse: Decodable {
        struct Model: Decodable { let name: String }
        let models: [Model]
    }

    private struct ChatResponse: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }

    private struct ChatRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        struct Options: Encodable { let temperature: Double }
        let model: String
        let stream: Bool
        let think: Bool // disables reasoning on thinking models, ignored by others (verified 2026-07-02)
        let messages: [Message]
        let keepAlive: String // model stays resident all day, avoids multi-second reloads between dictations
        let options: Options

        enum CodingKeys: String, CodingKey {
            case model, stream, think, messages, options
            case keepAlive = "keep_alive"
        }
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw OllamaError.badResponse
            }
            return data
        } catch let e as OllamaError {
            throw e
        } catch let e as URLError where e.code == .timedOut {
            throw OllamaError.timeout
        } catch {
            throw OllamaError.unreachable
        }
    }

    public func listModels() async throws -> [String] {
        let request = URLRequest(url: endpoint.appendingPathComponent("api/tags"),
                                 timeoutInterval: 3)
        let data = try await perform(request)
        guard let tags = try? JSONDecoder().decode(TagsResponse.self, from: data) else {
            throw OllamaError.badResponse
        }
        return tags.models.map(\.name)
    }

    public func chat(model: String, system: String, user: String,
                     timeoutSeconds: Double = 5) async throws -> String {
        var request = URLRequest(url: endpoint.appendingPathComponent("api/chat"),
                                 timeoutInterval: timeoutSeconds)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(ChatRequest(
            model: model, stream: false, think: false,
            messages: [.init(role: "system", content: system),
                       .init(role: "user", content: user)],
            keepAlive: "24h", options: ChatRequest.Options(temperature: 0)))
        let data = try await perform(request)
        guard let chat = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
            throw OllamaError.badResponse
        }
        return chat.message.content
    }
}
