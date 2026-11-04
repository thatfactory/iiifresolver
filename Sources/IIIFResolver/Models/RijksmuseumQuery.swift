import Foundation

/// Supported Rijksmuseum collection filters; empty optional filters are omitted.
public struct RijksmuseumQuery: Equatable, Sendable {
    public var creators: [String]
    public var title: String?
    public var description: String?
    public var objectType: String?
    public var materials: [String]
    public var techniques: [String]
    /// A year or provider-supported wildcard, such as `16??`.
    public var creationDate: String?
    public var objectNumber: String?
    /// Restricts discovery to objects with images by default.
    public var imageAvailable: Bool

    /// Creates filters without interpreting or translating the caller's search terms.
    public init(
        creators: [String] = [], title: String? = nil, description: String? = nil,
        objectType: String? = nil, materials: [String] = [], techniques: [String] = [],
        creationDate: String? = nil, objectNumber: String? = nil, imageAvailable: Bool = true
    ) {
        self.creators = creators
        self.title = title
        self.description = description
        self.objectType = objectType
        self.materials = materials
        self.techniques = techniques
        self.creationDate = creationDate
        self.objectNumber = objectNumber
        self.imageAvailable = imageAvailable
    }
}
