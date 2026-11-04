import Foundation

/// Search transport representation, separated from the package's public page model.
struct RijksmuseumSearchResponse: Decodable, Sendable {
    let id: URL
    let type: String
    let orderedItems: [LinkedArtRecord.Reference]
    var next: LinkedArtRecord.Reference?
    var partOf: Collection?

    /// Optional search collection totals.
    struct Collection: Decodable, Sendable {
        var totalItems: Int?
    }
}
