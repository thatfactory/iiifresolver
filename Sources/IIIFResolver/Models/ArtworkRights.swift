public import Foundation

/// A rights statement for an image, separate from the license of the catalogue metadata.
public struct ArtworkRights: Hashable, Sendable {
    /// The rights statement or license URI supplied by the provider.
    public let identifier: URL
    /// Available language-qualified labels for this statement.
    public let labels: [ArtworkText]
}
