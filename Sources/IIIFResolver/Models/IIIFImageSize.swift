import Foundation

/// Requested whole-image dimensions; neither option crops, distorts, or upscales.
public enum IIIFImageSize: Equatable, Sendable {
    /// Fits within positive pixel bounds and any smaller service limits.
    case fit(width: Int, height: Int)
    /// Requests the largest image permitted by the service, which may be below source resolution.
    case maximum
}
