import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// Isolated files whose lifetime is scoped to a single test.
final class TestFiles: Sendable {
    let directory: URL

    /// Creates an empty, uniquely named directory.
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Writes a test-owned temporary download.
    func write(_ data: Data, name: String = UUID().uuidString) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    /// Loads a synthetic fixture that mirrors current provider wire shapes.
    static func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    /// Creates a tiny valid image without network access or a checked-in binary fixture.
    static func jpeg(width: Int = 4, height: Int = 3) throws -> Data {
        let context = try #require(
            CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        )
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    /// Produces service metadata with independently configurable capabilities and limits.
    static func info(_ changes: [String: any Sendable] = [:]) throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: fixture("info")) as? [String: Any])
        for (key, value) in changes { object[key] = value }
        return try JSONSerialization.data(withJSONObject: object)
    }
}
