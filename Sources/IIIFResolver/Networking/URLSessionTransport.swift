import Foundation
import HTTPTypes
import HTTPTypesFoundation

/// Native transport with typed HTTP; cancellation and TLS behavior remain owned by URLSession.
struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    /// Creates a transport around the supplied native session.
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Retrieves response bytes using the typed URLSession overload.
    func data(for request: HTTPRequest) async throws -> (Data, HTTPResponse) {
        try await session.data(for: request)
    }

    /// Downloads to a native temporary file using the typed URLSession overload.
    func download(for request: HTTPRequest) async throws -> (URL, HTTPResponse) {
        try await session.download(for: request)
    }
}
