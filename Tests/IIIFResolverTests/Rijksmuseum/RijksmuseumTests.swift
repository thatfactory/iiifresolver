import Foundation
import HTTPTypes
import HTTPTypesFoundation
import Testing

@testable import IIIFResolver

/// Provider discovery, identity traversal, and educational metadata behavior.
@Suite(.tags(.unit))
struct RijksmuseumTests {
    @Test func searchEncodesFiltersAndFollowsOpaqueContinuation() async throws {
        // Given
        let transport = MockTransport { request in
            var object = try #require(JSONSerialization.jsonObject(with: TestFiles.fixture("search")) as? [String: Any])
            if request.path?.contains("pageToken") == true { object.removeValue(forKey: "next") }
            return (try JSONSerialization.data(withJSONObject: object), HTTPResponse(status: .ok))
        }
        let client = RijksmuseumClient(transport: transport)
        let query = RijksmuseumQuery(
            creators: ["A & B", "C+D"], title: "Study?", description: "blue", objectType: "drawing",
            materials: ["paper"], techniques: ["ink"], creationDate: "18??", objectNumber: "SK-A-*"
        )

        // When
        let page = try await client.search(query)
        let second = try #require(try await client.nextPage(after: page))
        #expect(try await client.nextPage(after: second) == nil)

        // Then
        let requests = await transport.requests
        #expect(requests.count == 2)
        let first = try #require(requests.first)
        #expect(first.method == .get)
        #expect(first.headerFields[.accept] == "application/ld+json, application/json")
        let url = try #require(first.url)
        #expect(url.absoluteString.contains("creator=C%2BD"))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.filter { $0.name == "creator" }.compactMap(\.value) == ["A & B", "C+D"])
        #expect(items.contains(URLQueryItem(name: "imageAvailable", value: "true")))
        #expect(items.contains(URLQueryItem(name: "creationDate", value: "18??")))
        #expect(requests[1].url == page.next)
        #expect(page.totalItems == 101)
        #expect(page.artworks.first?.id.absoluteString == "https://id.rijksmuseum.nl/2001")
    }

    @Test func artworkFollowsDistinctIDsAndPreservesMetadataAndImageRights() async throws {
        // Given
        let transport = fixtureTransport()
        let client = RijksmuseumClient(transport: transport)

        // When
        let artwork = try await client.artwork(for: reference())

        // Then
        #expect(artwork.titles.map(\.value) == ["A drawing", "Een tekening"])
        #expect(Set(artwork.titles.compactMap(\.languageIdentifier)).count == 2)
        #expect(artwork.creatorAttributions.first?.value == "Attributed to Artist")
        #expect(artwork.dates.first?.value == "circa 1884")
        #expect(artwork.descriptions.map(\.value) == ["A landscape."])
        #expect(artwork.materials.map(\.value) == ["paper", "papier"])
        #expect(artwork.techniques.first?.value == "pencil")
        #expect(artwork.sourceURLs.first?.host == "www.rijksmuseum.nl")
        #expect(
            artwork.images.map(\.serviceURL.absoluteString) == [
                "https://iiif.micr.io/sample", "https://iiif.micr.io/second",
            ])
        #expect(
            artwork.images.first?.rights.first?.identifier.absoluteString
                == "https://creativecommons.org/publicdomain/mark/1.0/")
        #expect(artwork.images.flatMap(\.rights).allSatisfy { !$0.identifier.absoluteString.contains("zero") })
        let paths = await transport.requests.compactMap(\.path)
        #expect(
            paths == [
                "/2001?_profile=la-framed", "/2029?_profile=la-framed", "/5008?_profile=la-framed",
                "/5010?_profile=la-framed",
            ])
    }

    @Test func absentOptionalMetadataAndImagesRemainEmpty() async throws {
        let transport = MockTransport { _ in
            (Data(#"{"id":"https://id.rijksmuseum.nl/2001","type":"HumanMadeObject"}"#.utf8), HTTPResponse(status: .ok))
        }
        let artwork = try await RijksmuseumClient(transport: transport).artwork(for: reference())
        #expect(artwork.images.isEmpty)
        #expect(artwork.titles.isEmpty)
        #expect(artwork.creatorAttributions.isEmpty)
    }

    @Test func linkedFailureDoesNotSilentlyOmitImages() async throws {
        let transport = MockTransport { request in
            if request.path?.hasPrefix("/2029") == true { return (Data(), HTTPResponse(status: .serviceUnavailable)) }
            return (try TestFiles.fixture("artwork"), HTTPResponse(status: .ok))
        }
        await #expect(throws: ResolverError.httpResponse(.serviceUnavailable)) {
            try await RijksmuseumClient(transport: transport).artwork(for: reference())
        }
    }

    @Test(arguments: [
        "https://example.com/2001", "http://id.rijksmuseum.nl/2001", "https://id.rijksmuseum.nl/2001/2029",
    ])
    func invalidIdentityMakesNoRequest(value: String) async throws {
        let transport = MockTransport()
        await #expect(throws: ResolverError.invalidURL) {
            try await RijksmuseumClient(transport: transport).artwork(for: ArtworkReference(id: URL(string: value)!))
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test(arguments: [
        ("not JSON", ResolverError.invalidMetadata),
        (
            #"{"id":"https://data.rijksmuseum.nl/search/collection","type":"OrderedCollectionPage","orderedItems":[],"next":{"id":"https://example.com/private"}}"#,
            ResolverError.invalidURL
        ),
    ])
    func malformedResponseAndForeignContinuationFail(json: String, expected: ResolverError) async throws {
        let transport = MockTransport { _ in (Data(json.utf8), HTTPResponse(status: .ok)) }
        await #expect(throws: expected) { try await RijksmuseumClient(transport: transport).search() }
    }

    // MARK: - Private

    /// Returns the synthetic artwork identity used by the linked fixtures.
    private func reference() -> ArtworkReference {
        ArtworkReference(id: URL(string: "https://id.rijksmuseum.nl/2001")!)
    }

    /// Serves records by their distinct IDs rather than by request sequence.
    private func fixtureTransport() -> MockTransport {
        MockTransport { request in
            let map = ["/2001": "artwork", "/2029": "visual", "/5008": "digital", "/5010": "digital-second"]
            let path = try #require(request.url?.path)
            let name = try #require(map[path])
            return (try TestFiles.fixture(name), HTTPResponse(status: .ok))
        }
    }
}
