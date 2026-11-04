import Foundation
import IIIFResolver
import Testing

/// Opt-in native integration coverage; external availability is never a normal CI dependency.
@Suite(.tags(.integration))
struct LiveIntegrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["IIIFRESOLVER_LIVE_TESTS"] == "1"))
    func searchToJPEG() async throws {
        let files = try TestFiles()
        let museum = RijksmuseumClient()
        let page = try await museum.search(RijksmuseumQuery(creators: ["vincent van gogh"], objectType: "drawing"))
        let reference = try #require(page.artworks.first)
        let artwork = try await museum.artwork(for: reference)
        #expect(!artwork.titles.isEmpty)
        let image = try #require(artwork.images.first)
        let client = IIIFImageClient()
        let service = try await client.resolve(image.serviceURL)
        let request = try client.imageRequest(for: service, size: .fit(width: 256, height: 256))
        let result = try await client.download(request, to: files.directory.appendingPathComponent("artwork.jpg"))
        #expect(result.byteCount > 0)
        #expect(result.dimensions.width <= 256)
        #expect(result.dimensions.height <= 256)
    }
}
