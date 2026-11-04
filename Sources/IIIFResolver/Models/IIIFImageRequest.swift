public import Foundation

/// A validated JPEG request that can be used for previews or downloaded by the client.
public struct IIIFImageRequest: Sendable {
    /// The complete IIIF image request URL.
    public let url: URL
    /// Bounds that the downloaded image must satisfy.
    public let maximumDimensions: ImageDimensions
    /// Maximum permitted pixel area, if supplied by the service.
    public let maximumPixelArea: Int?
}
