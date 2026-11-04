public import Foundation

/// One provider-sized result page; reading it does not resolve or download the artworks.
public struct RijksmuseumPage: Sendable {
    /// The current search URL.
    public let id: URL
    /// Artwork references in provider order.
    public let artworks: [ArtworkReference]
    /// An opaque continuation URL, passed back through `RijksmuseumClient.nextPage(after:)`.
    public let next: URL?
    /// The provider's total result count, when available.
    public let totalItems: Int?
}
