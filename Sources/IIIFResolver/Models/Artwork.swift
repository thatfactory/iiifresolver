public import Foundation

/// Museum-supplied educational metadata and image representations of one artwork.
public struct Artwork: Sendable {
    /// The persistent object reference.
    public let reference: ArtworkReference
    /// Available titles, retaining their supplied language identifiers.
    public let titles: [ArtworkText]
    /// Display attributions including uncertainty, roles, and qualifiers supplied by the museum.
    public let creatorAttributions: [ArtworkText]
    /// Display dates; these are not converted into an artificially precise calendar date.
    public let dates: [ArtworkText]
    /// Available descriptive text.
    public let descriptions: [ArtworkText]
    /// Available material names.
    public let materials: [ArtworkText]
    /// Available technique names.
    public let techniques: [ArtworkText]
    /// Museum catalogue pages, distinct from image URLs.
    public let sourceURLs: [URL]
    /// All discovered image services in provider order, deduplicated by service URL.
    public let images: [ArtworkImage]
}
