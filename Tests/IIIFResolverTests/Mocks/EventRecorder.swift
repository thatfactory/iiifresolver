import Foundation
import Synchronization

@testable import IIIFResolver

/// Captures logging events without querying the operating system's log store.
final class EventRecorder: Sendable {
    private let storage = Mutex<[ResolverLogger.Event]>([])
    var events: [ResolverLogger.Event] { storage.withLock { $0 } }
    var logger: ResolverLogger {
        ResolverLogger { [self] event in storage.withLock { $0.append(event) } }
    }
}
