public import Foundation

/// Validated IIIF Image API 3 service information, obtained through `IIIFImageClient.resolve(_:)`.
public struct IIIFImageService: Sendable {
    /// The canonical service identifier advertised by its information response.
    public let id: URL
    /// The source image dimensions; server output limits may be smaller.
    public let dimensions: ImageDimensions
    /// Independent maximum output dimensions advertised by the service.
    public let maximumDimensions: ImageDimensions
    /// Maximum output area in pixels, when advertised.
    public let maximumPixelArea: Int?
    let supportsWidth: Bool
    let sizes: [ImageDimensions]
}
