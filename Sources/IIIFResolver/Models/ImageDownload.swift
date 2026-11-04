public import Foundation

/// A validated JPEG published at the requested destination; its lifetime belongs to the caller.
public struct ImageDownload: Sendable {
    public let fileURL: URL
    public let dimensions: ImageDimensions
    public let byteCount: Int64
}
