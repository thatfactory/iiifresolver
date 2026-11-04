import Foundation

/// Searches Rijksmuseum and resolves its linked artwork, visual, and digital identities.
public struct RijksmuseumClient: Sendable {
    private let resource: HTTPResource
    private let logger: ResolverLogger

    /// Creates a client using native URLSession networking without requiring an API key.
    public init() {
        self.init(transport: URLSessionTransport())
    }

    /// Injects networking and diagnostics for deterministic package tests.
    init(transport: any HTTPTransport, logger: ResolverLogger = ResolverLogger()) {
        self.resource = HTTPResource(transport: transport)
        self.logger = logger
    }

    /// Retrieves one page without eagerly fetching artwork details or images.
    @concurrent public func search(_ query: RijksmuseumQuery = RijksmuseumQuery()) async throws -> RijksmuseumPage {
        try await logger.perform(.search) {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "data.rijksmuseum.nl"
            components.path = "/search/collection"
            components.queryItems = queryItems(query)
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
            guard let url = components.url else { throw ResolverError.invalidURL }
            return try await page(at: url)
        }
    }

    /// Follows the opaque continuation, or returns nil without networking when the page is last.
    @concurrent public func nextPage(after page: RijksmuseumPage) async throws -> RijksmuseumPage? {
        guard let next = page.next else { return nil }
        return try await logger.perform(.search) {
            try validateSearchURL(next)
            return try await self.page(at: next)
        }
    }

    /// Fetches artwork metadata and all linked image references; image bytes remain lazy.
    ///
    /// Missing image links produce an empty image list. A failed linked request throws instead
    /// of silently returning a partial representation list.
    @concurrent public func artwork(for reference: ArtworkReference) async throws -> Artwork {
        try await logger.perform(.artwork) {
            let record = try await entity(reference.id, expectedType: "HumanMadeObject")
            let images = try await images(for: record)
            let production = record.producedBy
            return Artwork(
                reference: ArtworkReference(id: record.id),
                titles: unique((record.identifiedBy ?? []).filter { $0.type == "Name" }.flatMap(\.values)),
                creatorAttributions: unique(production?.creatorAttributions ?? []),
                dates: unique((production?.timespan?.identifiedBy ?? []).flatMap(\.values)),
                descriptions: unique(
                    (record.referredToBy ?? []).filter {
                        $0.classified(as: "300435452") || $0.classified(as: "300080091")
                    }.flatMap(\.values)
                ),
                materials: unique((record.madeOf ?? []).flatMap(\.values)),
                techniques: unique((production?.technique ?? []).flatMap(\.values)),
                sourceURLs: unique(
                    (record.subjectOf ?? []).flatMap { $0.digitallyCarriedBy ?? [] }
                        .filter { $0.format == "text/html" }.flatMap { $0.accessPoint ?? [] }.map(\.id)
                ),
                images: images
            )
        }
    }

    // MARK: - Private

    /// Builds typed query items without mixing query values into URL syntax.
    private func queryItems(_ query: RijksmuseumQuery) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "imageAvailable", value: String(query.imageAvailable))]
        let fields: [(String, [String])] = [
            ("creator", query.creators), ("title", [query.title].compactMap { $0 }),
            ("description", [query.description].compactMap { $0 }),
            ("type", [query.objectType].compactMap { $0 }), ("material", query.materials),
            ("technique", query.techniques), ("creationDate", [query.creationDate].compactMap { $0 }),
            ("objectNumber", [query.objectNumber].compactMap { $0 }),
        ]
        for (name, values) in fields {
            items += values.filter { !$0.isEmpty }.map { URLQueryItem(name: name, value: $0) }
        }
        return items
    }

    /// Maps one provider response without assuming historical pagination parameter formats.
    private func page(at url: URL) async throws -> RijksmuseumPage {
        let response = try await resource.json(RijksmuseumSearchResponse.self, at: url)
        guard response.type == "OrderedCollectionPage",
            response.orderedItems.allSatisfy({ $0.type == "HumanMadeObject" })
        else { throw ResolverError.invalidMetadata }
        try validateSearchURL(response.id)
        if let next = response.next { try validateSearchURL(next.id) }
        for item in response.orderedItems { _ = try entityURL(item.id) }
        return RijksmuseumPage(
            id: response.id, artworks: response.orderedItems.map { ArtworkReference(id: $0.id) },
            next: response.next?.id, totalItems: response.partOf?.totalItems
        )
    }

    /// Restricts opaque continuation links to the provider's documented search boundary.
    private func validateSearchURL(_ url: URL) throws {
        _ = try HTTPResource.request(url, accept: "application/json")
        guard url.host == "data.rijksmuseum.nl", url.port == nil,
            url.path == "/search/collection"
        else { throw ResolverError.invalidURL }
    }

    /// Requests each exact persistent identifier in its framed Linked Art representation.
    private func entityURL(_ identifier: URL) throws -> URL {
        _ = try HTTPResource.request(identifier, accept: "application/json")
        guard ["id.rijksmuseum.nl", "data.rijksmuseum.nl"].contains(identifier.host),
            identifier.port == nil, identifier.query == nil,
            identifier.path.dropFirst().allSatisfy({ $0.isASCII && $0.isNumber }),
            identifier.path.count > 1,
            var components = URLComponents(url: identifier, resolvingAgainstBaseURL: false)
        else { throw ResolverError.invalidURL }
        components.host = "data.rijksmuseum.nl"
        components.queryItems = [URLQueryItem(name: "_profile", value: "la-framed")]
        guard let url = components.url else { throw ResolverError.invalidURL }
        return url
    }

    /// Validates type and identity before following a linked record.
    private func entity(_ identifier: URL, expectedType: String) async throws -> LinkedArtRecord {
        let record = try await resource.json(LinkedArtRecord.self, at: entityURL(identifier))
        _ = try entityURL(record.id)
        guard record.type == expectedType, record.id.path == identifier.path else {
            throw ResolverError.invalidMetadata
        }
        return record
    }

    /// Traverses each visual and digital record while keeping artwork and image rights separate.
    private func images(for record: LinkedArtRecord) async throws -> [ArtworkImage] {
        var images: [ArtworkImage] = []
        var indexes: [URL: Int] = [:]
        for reference in unique((record.shows ?? []).map(\.id)) {
            let visual = try await entity(reference, expectedType: "VisualItem")
            let rights = unique((visual.subjectTo ?? []).flatMap(\.values))
            for digitalReference in unique((visual.digitallyShownBy ?? []).map(\.id)) {
                let digital = try await entity(digitalReference, expectedType: "DigitalObject")
                for accessPoint in digital.accessPoint ?? [] {
                    let service = try serviceURL(from: accessPoint.id)
                    if let index = indexes[service] {
                        let previous = images[index]
                        images[index] = ArtworkImage(
                            id: previous.id, serviceURL: service, rights: unique(previous.rights + rights)
                        )
                    } else {
                        indexes[service] = images.count
                        images.append(ArtworkImage(id: digital.id, serviceURL: service, rights: rights))
                    }
                }
            }
        }
        return images
    }

    /// Removes only the documented image-request suffix, retaining the service's opaque identifier.
    private func serviceURL(from imageURL: URL) throws -> URL {
        _ = try HTTPResource.request(imageURL, accept: "image/jpeg")
        guard imageURL.host == "iiif.micr.io", imageURL.query == nil, imageURL.port == nil else {
            throw ResolverError.invalidURL
        }
        let pieces = imageURL.path.split(separator: "/")
        guard pieces.count == 5, pieces[1] == "full", pieces[3] == "0",
            pieces[4] == "default.jpg"
        else { throw ResolverError.invalidMetadata }
        let directory = imageURL.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard var components = URLComponents(url: directory, resolvingAgainstBaseURL: false) else {
            throw ResolverError.invalidURL
        }
        if components.percentEncodedPath.hasSuffix("/") { components.percentEncodedPath.removeLast() }
        guard let service = components.url else { throw ResolverError.invalidURL }
        return service
    }

    /// Deduplicates values without changing the provider's order.
    private func unique<Value: Hashable>(_ values: [Value]) -> [Value] {
        var seen: Set<Value> = []
        return values.filter { seen.insert($0).inserted }
    }
}
