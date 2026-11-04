public import Foundation

/// A discoverable image representation; service information is fetched only when requested.
public struct ArtworkImage: Hashable, Sendable {
    /// The provider's DigitalObject identifier.
    public let id: URL
    /// The IIIF image service base URL, accepted by `IIIFImageClient.resolve(_:)`.
    public let serviceURL: URL
    /// Image rights supplied by the associated VisualItem.
    public let rights: [ArtworkRights]
}
