public import Foundation
public import HTTPTypes

/// Failures exposed by discovery and downloads, without response bodies or private URLs.
public enum ResolverError: Error, Equatable, Sendable {
    /// The destination already exists and has not been changed.
    case destinationExists
    /// A local file operation failed.
    case fileSystem
    /// The server returned an unsuccessful HTTP status.
    case httpResponse(HTTPResponse.Status)
    /// The downloaded payload is not a valid JPEG image.
    case invalidImage
    /// Required service or provider metadata is invalid.
    case invalidMetadata
    /// The URL is not an eligible HTTPS resource or local destination.
    case invalidURL
    /// Native transport failed; cancellation is instead propagated as `CancellationError`.
    case transport(URLError.Code)
    /// Only IIIF Image API 3 services are supported.
    case unsupportedService
    /// The requested size cannot be produced within the service's advertised capabilities.
    case unsupportedSize
}
