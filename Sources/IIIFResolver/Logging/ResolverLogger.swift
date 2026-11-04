import AppLogger
import Foundation
import HTTPTypes

/// The sole package logging gateway; messages contain only fixed operation and outcome values.
struct ResolverLogger: Sendable {
    /// Stable diagnostic operations, independent of any consumer's UI or lifecycle.
    enum Operation: String, Sendable {
        case artwork, download, resolve, search
    }

    /// One terminal outcome per public asynchronous operation.
    enum Outcome: String, Sendable {
        case cancelled, failed, succeeded
    }

    /// Rendered diagnostic information exposed internally for deterministic tests.
    struct Event: Sendable {
        let operation: Operation
        let outcome: Outcome
        let reason: String
        var category: String { operation == .download ? "download" : "resolution" }
        var message: String { "🔎 \(operation.rawValue) | outcome=\(outcome.rawValue), reason=\(reason)" }
        var level: AppLogLevel { outcome == .failed ? .error : .debug }
        var isPrivate: Bool { false }
    }

    let sink: @Sendable (Event) -> Void

    /// Uses AppLogger in production, or an injected event sink in tests.
    init(sink: @escaping @Sendable (Event) -> Void = Self.emit) {
        self.sink = sink
    }

    /// Emits exactly one outcome and normalizes transport and cancellation failures.
    func perform<Value: Sendable>(
        _ operation: Operation, body: @Sendable () async throws -> Value
    ) async throws -> Value {
        do {
            try Task.checkCancellation()
            let value = try await body()
            sink(Event(operation: operation, outcome: .succeeded, reason: "none"))
            return value
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                sink(Event(operation: operation, outcome: .cancelled, reason: "cancelled"))
                throw CancellationError()
            }
            let failure: ResolverError
            if let known = error as? ResolverError {
                failure = known
            } else if let network = error as? URLError {
                failure = .transport(network.code)
            } else {
                failure = .invalidMetadata
            }
            sink(Event(operation: operation, outcome: .failed, reason: Self.reason(failure)))
            throw failure
        }
    }

    // MARK: - Private

    /// Emits only gateway-formatted, content-free messages.
    private static func emit(_ event: Event) {
        AppLogger(subsystem: "com.thatfactory.iiifresolver", category: event.category)
            .log(level: event.level, event.message, isPrivate: event.isPrivate)
    }

    /// Maps failures to stable diagnostic categories without interpolating associated values.
    private static func reason(_ error: ResolverError) -> String {
        switch error {
        case .destinationExists: "destinationExists"
        case .fileSystem: "fileSystem"
        case .httpResponse(let status): "httpResponse, status=\(status.code)"
        case .invalidImage: "invalidImage"
        case .invalidMetadata: "invalidMetadata"
        case .invalidURL: "invalidURL"
        case .transport(let code): "transport, code=\(code.rawValue)"
        case .unsupportedService: "unsupportedService"
        case .unsupportedSize: "unsupportedSize"
        }
    }
}
