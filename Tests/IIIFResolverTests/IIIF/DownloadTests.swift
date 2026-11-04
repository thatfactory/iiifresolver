import Foundation
import HTTPTypes
import Testing

@testable import IIIFResolver

/// Download validation, cancellation, cleanup, and non-overwriting publication.
@Suite(.tags(.unit))
struct DownloadTests {
    @Test func downloadPublishesCompleteJPEGAndRemovesTemporaryFile() async throws {
        let files = try TestFiles()
        let data = try TestFiles.jpeg()
        let temporary = try files.write(data)
        let recorder = EventRecorder()
        let transport = MockTransport(download: { _ in (temporary, jpegResponse()) })
        let client = IIIFImageClient(transport: transport, logger: recorder.logger)
        let destination = files.directory.appendingPathComponent("result.jpg")
        let result = try await client.download(request(), to: destination)
        #expect(try Data(contentsOf: result.fileURL) == data)
        #expect(result.dimensions == ImageDimensions(width: 4, height: 3))
        #expect(result.byteCount == data.count)
        #expect(!FileManager.default.fileExists(atPath: temporary.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.directory.path) == ["result.jpg"])
        #expect(recorder.events.count == 1)
        #expect(recorder.events.first?.outcome == .succeeded)
        #expect(await transport.requests.first?.headerFields[.accept] == "image/jpeg")
    }

    @Test func existingDestinationIsUnchangedWithoutNetworkRequest() async throws {
        let files = try TestFiles()
        let original = Data("original".utf8)
        let destination = try files.write(original, name: "existing.jpg")
        let transport = MockTransport()
        await #expect(throws: ResolverError.destinationExists) {
            try await IIIFImageClient(transport: transport).download(request(), to: destination)
        }
        #expect(try Data(contentsOf: destination) == original)
        #expect(await transport.requests.isEmpty)
    }

    @Test func invalidPayloadLeavesNoDestinationOrTemporaryFile() async throws {
        let files = try TestFiles()
        let temporary = try files.write(Data("not an image".utf8))
        let transport = MockTransport(download: { _ in (temporary, jpegResponse()) })
        await #expect(throws: ResolverError.invalidImage) {
            try await IIIFImageClient(transport: transport).download(
                request(), to: files.directory.appendingPathComponent("result.jpg"))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.directory.path).isEmpty)
    }

    @Test(arguments: [HTTPResponse.Status.forbidden, .notFound, .tooManyRequests, .serviceUnavailable, .partialContent])
    func unsuccessfulResponseIsNotPublished(status: HTTPResponse.Status) async throws {
        let files = try TestFiles()
        let temporary = try files.write(TestFiles.jpeg())
        let transport = MockTransport(download: { _ in (temporary, HTTPResponse(status: status)) })
        await #expect(throws: ResolverError.httpResponse(status)) {
            try await IIIFImageClient(transport: transport).download(
                request(), to: files.directory.appendingPathComponent("result.jpg"))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.directory.path).isEmpty)
    }

    @Test func oversizedImageIsRejectedDespiteSuccessfulHTTP() async throws {
        let files = try TestFiles()
        let temporary = try files.write(TestFiles.jpeg(width: 10, height: 10))
        let transport = MockTransport(download: { _ in (temporary, jpegResponse()) })
        await #expect(throws: ResolverError.invalidImage) {
            try await IIIFImageClient(transport: transport).download(
                request(), to: files.directory.appendingPathComponent("result.jpg"))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.directory.path).isEmpty)
    }

    @Test func cancellationAfterTransferCleansTemporaryFile() async throws {
        let files = try TestFiles()
        let temporary = try files.write(TestFiles.jpeg())
        let recorder = EventRecorder()
        let transport = MockTransport(download: { _ in
            withUnsafeCurrentTask { $0?.cancel() }
            return (temporary, jpegResponse())
        })
        let task = Task {
            try await IIIFImageClient(transport: transport, logger: recorder.logger)
                .download(request(), to: files.directory.appendingPathComponent("result.jpg"))
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.directory.path).isEmpty)
        #expect(recorder.events.map(\.outcome) == [.cancelled])
    }

    @Test func competingDownloadsDoNotOverwriteOneAnother() async throws {
        let files = try TestFiles()
        let bytes = try TestFiles.jpeg()
        let transport = MockTransport(download: { _ in (try files.write(bytes), jpegResponse()) })
        let client = IIIFImageClient(transport: transport)
        let destination = files.directory.appendingPathComponent("result.jpg")
        let outcomes = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<2 {
                group.addTask {
                    do {
                        _ = try await client.download(request(), to: destination)
                        return true
                    } catch {
                        #expect(error as? ResolverError == .destinationExists)
                        return false
                    }
                }
            }
            var results: [Bool] = []
            for await result in group { results.append(result) }
            return results
        }
        #expect(outcomes.filter { $0 }.count == 1)
        #expect(try Data(contentsOf: destination) == bytes)
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.directory.path) == ["result.jpg"])
    }

    @Test func missingDestinationParentReportsFileSystemFailureAndCleansUp() async throws {
        let files = try TestFiles()
        let temporary = try files.write(TestFiles.jpeg())
        let transport = MockTransport(download: { _ in (temporary, jpegResponse()) })
        await #expect(throws: ResolverError.fileSystem) {
            try await IIIFImageClient(transport: transport)
                .download(request(), to: files.directory.appendingPathComponent("missing/result.jpg"))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.directory.path).isEmpty)
    }

    // MARK: - Private

    /// A bounded request matching the generated JPEG fixture.
    private func request() -> IIIFImageRequest {
        IIIFImageRequest(
            url: URL(string: "https://example.com/image/full/4,/0/default.jpg")!,
            maximumDimensions: ImageDimensions(width: 4, height: 3), maximumPixelArea: 12)
    }

    /// A complete JPEG response using typed HTTP headers and status.
    private func jpegResponse() -> HTTPResponse {
        HTTPResponse(status: .ok, headerFields: [.contentType: "image/jpeg"])
    }
}
