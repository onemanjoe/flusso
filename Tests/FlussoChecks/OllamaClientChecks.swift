import Foundation
import FlussoCore

final class MockURLProtocol: URLProtocol {
    // Return nil to stall the request until the client times out.
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data)?)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let result = Self.handler?(request) else { return } // stall
        let (status, data) = result
        let resp = HTTPURLResponse(url: request.url!, statusCode: status,
                                   httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

func mockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

func ollamaClientChecks() async {
    let endpoint = URL(string: "http://localhost:11434")!

    await Harness.check("listModels parses tags") {
        MockURLProtocol.handler = { _ in
            (200, Data(#"{"models":[{"name":"qwen2.5:7b"},{"name":"gemma3:12b"}]}"#.utf8))
        }
        let models = try await OllamaClient(endpoint: endpoint, session: mockSession()).listModels()
        try Harness.expect(models == ["qwen2.5:7b", "gemma3:12b"], "got \(models)")
    }
    await Harness.check("chat returns message content") {
        MockURLProtocol.handler = { req in
            guard req.url?.path == "/api/chat" else { return (404, Data()) }
            return (200, Data(#"{"message":{"role":"assistant","content":"Testo pulito."},"done":true}"#.utf8))
        }
        let text = try await OllamaClient(endpoint: endpoint, session: mockSession())
            .chat(model: "qwen2.5:7b", system: "s", user: "u")
        try Harness.expect(text == "Testo pulito.", "got \(text)")
    }
    await Harness.check("chat times out as OllamaError.timeout") {
        MockURLProtocol.handler = { _ in nil } // stall
        do {
            _ = try await OllamaClient(endpoint: endpoint, session: mockSession())
                .chat(model: "m", system: "s", user: "u", timeoutSeconds: 0.3)
            try Harness.expect(false, "no error thrown")
        } catch let e as OllamaError {
            try Harness.expect(e == .timeout, "got \(e)")
        }
    }
    await Harness.check("chat garbage body is badResponse") {
        MockURLProtocol.handler = { _ in (200, Data("garbage".utf8)) }
        do {
            _ = try await OllamaClient(endpoint: endpoint, session: mockSession())
                .chat(model: "m", system: "s", user: "u")
            try Harness.expect(false, "no error thrown")
        } catch let e as OllamaError {
            try Harness.expect(e == .badResponse, "got \(e)")
        }
    }
}
