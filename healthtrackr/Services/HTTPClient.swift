import Foundation

nonisolated enum NetworkError: Error, Equatable {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)
    case decodingFailed(Error)

    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse):
            return true
        case let (.httpError(lCode, lBody), .httpError(rCode, rBody)):
            return lCode == rCode && lBody == rBody
        case (.decodingFailed, .decodingFailed):
            return true
        default:
            return false
        }
    }
}

actor HTTPClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func send<Response: Decodable & Sendable>(
        request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8)
            )
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
