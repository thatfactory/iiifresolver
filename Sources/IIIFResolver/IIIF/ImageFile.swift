import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Validates downloaded JPEGs and publishes complete files without replacing existing destinations.
enum ImageFile {
    /// Checks a caller-owned destination without creating parent directories.
    static func validateDestination(_ destination: URL) throws {
        guard destination.isFileURL, destination.query == nil, destination.fragment == nil,
            destination.lastPathComponent != "", destination.host == nil || destination.host == "localhost"
        else { throw ResolverError.invalidURL }
        if (try? destination.resourceValues(forKeys: [.isRegularFileKey])) != nil
            || FileManager.default.fileExists(atPath: destination.path)
            || (try? FileManager.default.destinationOfSymbolicLink(atPath: destination.path)) != nil
        {
            throw ResolverError.destinationExists
        }
    }

    /// Inspects the JPEG without decompressing a full-resolution bitmap into memory.
    static func inspect(_ file: URL, request: IIIFImageRequest) throws -> ImageDimensions {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
            CGImageSourceGetType(source) as String? == UTType.jpeg.identifier,
            CGImageSourceGetCount(source) == 1,
            CGImageSourceGetStatus(source) == .statusComplete,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0,
            width <= request.maximumDimensions.width, height <= request.maximumDimensions.height,
            request.maximumPixelArea.map({ Double(width) * Double(height) <= Double($0) }) ?? true
        else { throw ResolverError.invalidImage }
        // A tiny decoded thumbnail checks image data while keeping working memory bounded.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 1,
            kCGImageSourceShouldCache: false,
        ]
        guard CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) != nil,
            CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete
        else { throw ResolverError.invalidImage }
        return ImageDimensions(width: width, height: height)
    }

    /// Stages on the destination volume, then creates an atomic, non-overwriting hard link.
    static func publish(_ temporary: URL, to destination: URL) throws -> Int64 {
        try validateDestination(destination)
        let staged = destination.deletingLastPathComponent()
            .appendingPathComponent(".iiifresolver-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: staged) }
        do {
            try FileManager.default.copyItem(at: temporary, to: staged)
            let size = try staged.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            try Task.checkCancellation()
            // Unlike a replace or rename, linking fails atomically when a competing writer wins.
            try FileManager.default.linkItem(at: staged, to: destination)
            return Int64(size)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if FileManager.default.fileExists(atPath: destination.path)
                || (try? FileManager.default.destinationOfSymbolicLink(atPath: destination.path)) != nil
            {
                throw ResolverError.destinationExists
            }
            throw ResolverError.fileSystem
        }
    }
}
