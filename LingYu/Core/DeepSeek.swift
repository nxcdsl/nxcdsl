import Foundation

enum DeepSeekError: LocalizedError {
    case badKey
    case http(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .badKey: return "API Key 不对"
        case .http(let c): return "请求失败 (\(c))"
        case .empty: return "没有返回内容"
        }
    }
}

struct DeepSeekClient {

    let key: String
    private static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    // MARK: - 流式

    func stream(messages: [[String: Any]],
                maxTokens: Int,
                onDelta: @escaping (String) -> Void) async throws -> Usage {

        let (bytes, response) = try await URLSession.shared.bytes(for: try request(messages, maxTokens: maxTokens, stream: true))
        guard let http = response as? HTTPURLResponse else { throw DeepSeekError.empty }
        guard http.statusCode == 200 else {
            throw http.statusCode == 401 ? DeepSeekError.badKey : DeepSeekError.http(http.statusCode)
        }

        var usage = Usage()
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = String(line.dropFirst(5)).trimmed
            if payload.isEmpty { continue }
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            if let u = obj["usage"] as? [String: Any] {
                usage.input = (u["prompt_tokens"] as? Int) ?? usage.input
                usage.output = (u["completion_tokens"] as? Int) ?? usage.output
            }
            if let choices = obj["choices"] as? [[String: Any]],
               let delta = choices.first?["delta"] as? [String: Any],
               let piece = delta["content"] as? String, !piece.isEmpty {
                onDelta(piece)
            }
        }
        return usage
    }

    // MARK: - 一次性

    func complete(prompt: String, maxTokens: Int) async throws -> String {
        try await once([
            ["role": "system", "content": "只输出要求的格式，不要解释。"],
            ["role": "user", "content": prompt]
        ], maxTokens: maxTokens)
    }

    func completeWithImage(prompt: String, imageBase64: String, maxTokens: Int) async throws -> String {
        try await once([
            ["role": "system", "content": "只输出要求的 JSON，不要解释。"],
            ["role": "user", "content": [
                ["type": "text", "text": prompt],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]]
            ]]
        ], maxTokens: maxTokens)
    }

    private func once(_ messages: [[String: Any]], maxTokens: Int) async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: try request(messages, maxTokens: maxTokens, stream: false))
        guard let http = response as? HTTPURLResponse else { throw DeepSeekError.empty }
        guard http.statusCode == 200 else {
            throw http.statusCode == 401 ? DeepSeekError.badKey : DeepSeekError.http(http.statusCode)
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let text = msg["content"] as? String else { throw DeepSeekError.empty }
        return text
    }

    // MARK: - 请求体

    private func request(_ messages: [[String: Any]], maxTokens: Int, stream: Bool) throws -> URLRequest {
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "model": "deepseek-flash",
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": 0.8,
            "stream": stream
        ]
        if stream {
            body["stream_options"] = ["include_usage": true]
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }
}
