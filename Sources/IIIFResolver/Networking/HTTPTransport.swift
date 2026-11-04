import Foundation
import HTTPTypes

/// Injectable native HTTP boundary used by both provider discovery and image retrieval.
protocol HTTPTransport: Sendable {
    /// Retrieves a metadata response in memory.
    func data(for request: HTTPRequest) async throws -> (Data, HTTPResponse)
    /// Downloads bytes to a temporary file whose ownership transfers to the caller.
    func download(for request: HTTPRequest) async throws -> (URL, HTTPResponse)
}
