import Foundation

// MARK: - Request

nonisolated struct AnthropicMessageRequest: Encodable, Sendable {
    let model: String
    let maxTokens: Int
    let messages: [Message]

    nonisolated struct Message: Encodable, Sendable {
        let role: String
        let content: String
    }

    nonisolated enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

// MARK: - Response

nonisolated struct AnthropicMessageResponse: Codable, Sendable {
    let content: [ContentBlock]

    nonisolated struct ContentBlock: Codable, Sendable {
        let type: String
        let text: String?
    }

    var text: String? {
        content.first(where: { $0.type == "text" })?.text
    }
}
