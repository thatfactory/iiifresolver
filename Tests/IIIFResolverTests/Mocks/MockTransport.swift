import Foundation
import HTTPTypes
import HTTPTypesFoundation

@testable import IIIFResolver

/// Records typed requests while serving deterministic responses or controlled failures.
actor MockTransport: HTTPTransport {
    typealias DataHandler = @Sendable (HTTPRequest) async throws -> (Data, HTTPResponse)
    typealias DownloadHandler = @Sendable (HTTPRequest) async throws -> (URL, HTTPResponse)
    private let dataHandler: DataHandler
    private let downloadHandler: DownloadHandler
    private(set) var requests: [HTTPRequest] = []

    /// Configures only the operations needed by the test.
    init(
        data: @escaping DataHandler = { _ in throw ResolverError.invalidMetadata },
        download: @escaping DownloadHandler = { _ in throw ResolverError.invalidImage }
    ) {
        self.dataHandler = data
        self.downloadHandler = download
    }

    /// Records and serves an in-memory request.
    func data(for request: HTTPRequest) async throws -> (Data, HTTPResponse) {
        requests.append(request)
        return try await dataHandler(request)
    }

    /// Records and serves a temporary-file download.
    func download(for request: HTTPRequest) async throws -> (URL, HTTPResponse) {
        requests.append(request)
        return try await downloadHandler(request)
    }
}
