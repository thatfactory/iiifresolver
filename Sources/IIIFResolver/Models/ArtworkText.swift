public import Foundation

/// A supplied textual value with its original language identifier, without inferred translation.
public struct ArtworkText: Hashable, Sendable {
    /// The provider's text, including attribution qualifiers when present.
    public let value: String
    /// The provider's language vocabulary URI, or nil when no language was supplied.
    public let languageIdentifier: URL?
}
