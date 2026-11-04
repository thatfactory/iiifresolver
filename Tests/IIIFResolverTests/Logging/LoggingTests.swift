import AppLogger
import Foundation
import HTTPTypes
import Testing

@testable import IIIFResolver

/// Outcome coverage for every logged operation without access to the persisted OS log.
@Suite(.tags(.unit))
struct LoggingTests {
    @Test(arguments: [ResolverLogger.Operation.artwork, .download, .resolve, .search])
    func everyOperationLogsOneSafeSuccess(operation: ResolverLogger.Operation) async throws {
        let recorder = EventRecorder()
        let result = try await recorder.logger.perform(operation) { 42 }
        #expect(result == 42)
        let event = try #require(recorder.events.first)
        #expect(recorder.events.count == 1)
        #expect(event.message == "🔎 \(operation.rawValue) | outcome=succeeded, reason=none")
        #expect(event.level == .debug)
        #expect(!event.isPrivate)
        #expect(event.category == (operation == .download ? "download" : "resolution"))
    }

    @Test(arguments: [
        ResolverError.destinationExists, .fileSystem, .httpResponse(.forbidden), .invalidImage, .invalidMetadata,
        .invalidURL, .transport(.notConnectedToInternet), .unsupportedService, .unsupportedSize,
    ])
    func failuresUseFixedReasons(error: ResolverError) async throws {
        let recorder = EventRecorder()
        await #expect(throws: error) {
            try await recorder.logger.perform(.resolve) { () throws -> Void in throw error }
        }
        let event = try #require(recorder.events.first)
        #expect(recorder.events.count == 1)
        #expect(event.message.hasPrefix("🔎 resolve | outcome=failed, reason="))
        #expect(event.level == .error)
        #expect(!event.message.contains("http:"))
        #expect(!event.isPrivate)
    }

    @Test(arguments: [ResolverLogger.Operation.artwork, .download, .resolve, .search])
    func nativeCancellationIsNormalized(operation: ResolverLogger.Operation) async throws {
        let recorder = EventRecorder()
        await #expect(throws: CancellationError.self) {
            try await recorder.logger.perform(operation) { () throws -> Void in throw URLError(.cancelled) }
        }
        #expect(recorder.events.map(\.outcome) == [.cancelled])
        #expect(recorder.events.first?.level == .debug)
    }

    @Test func nativeTransportErrorsArePreservedWithoutTheirUserInfo() async throws {
        let recorder = EventRecorder()
        let transport = MockTransport { _ in
            throw URLError(
                .timedOut,
                userInfo: [NSURLErrorFailingURLErrorKey: URL(string: "https://private.example/search?q=secret")!])
        }
        await #expect(throws: ResolverError.transport(.timedOut)) {
            try await RijksmuseumClient(transport: transport, logger: recorder.logger).search()
        }
        #expect(recorder.events.count == 1)
        #expect(recorder.events.first?.message == "🔎 search | outcome=failed, reason=transport, code=-1001")
    }
}
