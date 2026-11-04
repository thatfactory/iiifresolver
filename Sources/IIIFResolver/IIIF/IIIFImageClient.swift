public import Foundation
import HTTPTypes

/// Provider-independent IIIF Image API 3 service resolution and cancellable JPEG downloads.
public struct IIIFImageClient: Sendable {
    private let resource: HTTPResource
    private let logger: ResolverLogger

    /// Creates a client using native URLSession networking.
    public init() {
        self.init(transport: URLSessionTransport())
    }

    /// Injects networking and diagnostics for deterministic package tests.
    init(transport: any HTTPTransport, logger: ResolverLogger = ResolverLogger()) {
        self.resource = HTTPResource(transport: transport)
        self.logger = logger
    }

    /// Resolves a service base URL or its `info.json` URL without fetching image bytes.
    @concurrent public func resolve(_ serviceURL: URL) async throws -> IIIFImageService {
        try await logger.perform(.resolve) {
            _ = try HTTPResource.request(serviceURL, accept: "application/json")
            guard serviceURL.query == nil else { throw ResolverError.invalidURL }
            let info =
                serviceURL.lastPathComponent == "info.json"
                ? serviceURL : serviceURL.appendingPathComponent("info.json")
            let response = try await resource.json(IIIFInfoResponse.self, at: info)
            return try response.service()
        }
    }

    /// Creates a preview/download request without networking or logging side effects.
    public func imageRequest(for service: IIIFImageService, size: IIIFImageSize) throws -> IIIFImageRequest {
        try IIIFRequestBuilder.request(service: service, size: size)
    }

    /// Downloads and validates a JPEG, then publishes it without overwriting the destination.
    ///
    /// The destination's parent must already exist and support hard links. On failure or
    /// cancellation before publication, temporary files are removed. Once published, success
    /// is returned even if cancellation arrives after that commit point.
    @concurrent public func download(_ image: IIIFImageRequest, to destination: URL) async throws -> ImageDownload {
        try await logger.perform(.download) {
            try ImageFile.validateDestination(destination)
            let request = try HTTPResource.request(image.url, accept: "image/jpeg")
            let (temporary, response) = try await resource.transport.download(for: request)
            defer { try? FileManager.default.removeItem(at: temporary) }
            try Task.checkCancellation()
            try HTTPResource.validate(response)
            guard
                response.headerFields[.contentType]?.split(separator: ";").first?
                    .trimmingCharacters(in: .whitespaces).lowercased() == "image/jpeg"
            else { throw ResolverError.invalidImage }
            let dimensions = try ImageFile.inspect(temporary, request: image)
            try Task.checkCancellation()
            let byteCount = try ImageFile.publish(temporary, to: destination)
            return ImageDownload(fileURL: destination, dimensions: dimensions, byteCount: byteCount)
        }
    }
}
