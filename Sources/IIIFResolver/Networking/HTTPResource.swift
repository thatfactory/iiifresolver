import Foundation
import HTTPTypes
import HTTPTypesFoundation

/// Shared status validation and JSON retrieval, without duplicate operation logging.
struct HTTPResource: Sendable {
    let transport: any HTTPTransport

    /// Builds a GET request after validating the public HTTPS resource.
    static func request(_ url: URL, accept: String) throws -> HTTPRequest {
        guard url.scheme == "https", url.host != nil, url.user == nil, url.password == nil,
            url.fragment == nil
        else { throw ResolverError.invalidURL }
        var request = HTTPRequest(method: .get, url: url)
        request.headerFields[.accept] = accept
        return request
    }

    /// Requires a complete successful GET response, rejecting partial responses.
    static func validate(_ response: HTTPResponse) throws {
        guard response.status == .ok else { throw ResolverError.httpResponse(response.status) }
    }

    /// Fetches and decodes JSON; unknown fields are ignored by focused Decodable models.
    func json<Value: Decodable & Sendable>(_ type: Value.Type, at url: URL) async throws -> Value {
        try Task.checkCancellation()
        let request = try Self.request(url, accept: "application/ld+json, application/json")
        let (data, response) = try await transport.data(for: request)
        try Task.checkCancellation()
        try Self.validate(response)
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(type, from: data)
        } catch {
            throw ResolverError.invalidMetadata
        }
    }
}
