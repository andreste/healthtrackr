import Foundation

protocol HTTPClientProviding: Sendable {
    func send<Response: Decodable & Sendable>(
        request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response
}

extension HTTPClient: HTTPClientProviding {}
