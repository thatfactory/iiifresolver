import Foundation
import HTTPTypes
import Testing

@testable import IIIFResolver

/// Protocol negotiation and capability-aware request sizing.
@Suite(.tags(.unit))
struct IIIFSizingTests {
    @Test func maximumUsesProtocolKeywordInsteadOfOriginalWidthCommaMax() async throws {
        let client = client()
        let service = try await client.resolve(URL(string: "https://iiif.micr.io/sample")!)
        let request = try client.imageRequest(for: service, size: .maximum)
        #expect(request.url.absoluteString == "https://iiif.micr.io/sample/full/max/0/default.jpg")
        #expect(service.dimensions == ImageDimensions(width: 5686, height: 4134))
        #expect(request.maximumPixelArea == 17_550_000)
    }

    @Test(arguments: [(256, 256), (4096, 2160), (6000, 6000), (100, 1)])
    func fittedRequestsRespectAreaAndBounds(width: Int, height: Int) async throws {
        let client = client()
        let service = try await client.resolve(URL(string: "https://iiif.micr.io/sample/info.json")!)
        let request = try client.imageRequest(for: service, size: .fit(width: width, height: height))
        let size = request.url.pathComponents.dropLast(2).last!
        let outputWidth = try #require(Int(size.dropLast()))
        let outputHeight = Int(ceil(Double(outputWidth) * 4134 / 5686))
        #expect(outputWidth <= width)
        #expect(outputHeight <= height)
        #expect(outputWidth <= 5686)
        #expect(outputWidth * outputHeight <= 17_550_000)
        #expect(size.hasSuffix(","))
    }

    @Test func widthLimitAlsoBoundsHeightWhenHeightIsUnspecified() async throws {
        let data = try TestFiles.info(["maxWidth": 100])
        let client = client(data: data)
        let service = try await client.resolve(URL(string: "https://iiif.micr.io/sample")!)
        #expect(service.maximumDimensions == ImageDimensions(width: 100, height: 100))
    }

    @Test func levelZeroChoosesLargestAdvertisedSizeWithinBounds() async throws {
        let data = try TestFiles.info([
            "profile": "level0", "sizes": [["width": 100, "height": 73], ["width": 200, "height": 145]],
        ])
        let client = client(data: data)
        let service = try await client.resolve(URL(string: "https://iiif.micr.io/sample")!)
        let request = try client.imageRequest(for: service, size: .fit(width: 150, height: 150))
        #expect(request.url.path.contains("/100,73/"))
        #expect(throws: ResolverError.unsupportedSize) {
            try client.imageRequest(for: service, size: .fit(width: 50, height: 50))
        }
    }

    @Test(arguments: [0, -1, Int.min])
    func invalidBoundsAreRejected(bound: Int) async throws {
        let client = client()
        let service = try await client.resolve(URL(string: "https://iiif.micr.io/sample")!)
        #expect(throws: ResolverError.unsupportedSize) {
            try client.imageRequest(for: service, size: .fit(width: bound, height: 100))
        }
    }

    @Test func unsupportedVersionIsExplicit() async throws {
        let data = Data(
            #"{"@id":"https://example.com/image","@context":"http://iiif.io/api/image/2/context.json","width":100,"height":100}"#
                .utf8)
        await #expect(throws: ResolverError.unsupportedService) {
            try await client(data: data).resolve(URL(string: "https://example.com/image")!)
        }
    }

    @Test(arguments: [0, -1, Int.max])
    func invalidServiceDimensionsAreRejected(width: Int) async throws {
        let data = try TestFiles.info(["width": width])
        await #expect(throws: ResolverError.invalidMetadata) {
            try await client(data: data).resolve(URL(string: "https://iiif.micr.io/sample")!)
        }
    }

    @Test func widthResizingCanBeAdvertisedByLevelZero() async throws {
        let data = try TestFiles.info(["profile": "level0", "extraFeatures": ["sizeByW"]])
        let client = client(data: data)
        let service = try await client.resolve(URL(string: "https://iiif.micr.io/sample")!)
        let request = try client.imageRequest(for: service, size: .fit(width: 256, height: 256))
        #expect(request.url.path.contains("/256,/"))
    }

    // MARK: - Private

    /// Creates a client serving one information document.
    private func client(data: Data? = nil) -> IIIFImageClient {
        IIIFImageClient(
            transport: MockTransport { _ in
                (try data ?? TestFiles.fixture("info"), HTTPResponse(status: .ok))
            })
    }
}
