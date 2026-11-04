public import Foundation

/// The persistent provider identity of an artwork, independent of its visual and digital identities.
public struct ArtworkReference: Hashable, Sendable {
    /// The canonical Rijksmuseum persistent identifier.
    public let id: URL

    /// Creates a reference; the provider validates its URL before making a request.
    public init(id: URL) {
        self.id = id
    }
}
