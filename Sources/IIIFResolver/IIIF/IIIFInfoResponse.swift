import Foundation

/// Focused decoding of IIIF Image API 3 metadata; unrelated extensions remain ignored.
struct IIIFInfoResponse: Decodable, Sendable {
    var id: URL?
    var type: String?
    var protocolIdentifier: String?
    var profile: String?
    var width: Int?
    var height: Int?
    var maxWidth: Int?
    var maxHeight: Int?
    var maxArea: Int?
    var sizes: [Size]?
    var extraFeatures: [String]?

    /// Maps the reserved protocol field to a descriptive Swift property.
    enum CodingKeys: String, CodingKey {
        case extraFeatures, height, id, maxArea, maxHeight, maxWidth, profile, sizes, type, width
        case protocolIdentifier = "protocol"
    }

    /// A discrete supported whole-image size, including static level-zero services.
    struct Size: Decodable, Sendable {
        let width: Int
        let height: Int
    }

    /// Validates service capabilities and output limits before constructing public values.
    func service() throws -> IIIFImageService {
        guard type == "ImageService3", protocolIdentifier == "http://iiif.io/api/image" else {
            throw ResolverError.unsupportedService
        }
        guard let id, let width, let height, let profile,
            ["level0", "level1", "level2"].contains(profile),
            Self.validDimension(width), Self.validDimension(height),
            maxWidth.map(Self.validDimension) ?? true, maxHeight.map(Self.validDimension) ?? true,
            maxArea.map({ $0 > 0 }) ?? true, maxHeight == nil || maxWidth != nil
        else { throw ResolverError.invalidMetadata }
        _ = try HTTPResource.request(id, accept: "application/json")
        guard id.query == nil else { throw ResolverError.invalidMetadata }
        let bounds = ImageDimensions(
            width: min(width, maxWidth ?? width), height: min(height, maxHeight ?? maxWidth ?? height)
        )
        let advertised = sizes ?? []
        guard
            advertised.allSatisfy({ size in
                Self.validDimension(size.width) && Self.validDimension(size.height)
                    && size.width <= bounds.width && size.height <= bounds.height
                    && (maxArea.map { area in Double(size.width) * Double(size.height) <= Double(area) } ?? true)
            })
        else { throw ResolverError.invalidMetadata }
        return IIIFImageService(
            id: id, dimensions: ImageDimensions(width: width, height: height),
            maximumDimensions: bounds, maximumPixelArea: maxArea,
            supportsWidth: profile != "level0" || extraFeatures?.contains("sizeByW") == true,
            sizes: advertised.map { ImageDimensions(width: $0.width, height: $0.height) }
        )
    }

    /// Limits pixel arithmetic to meaningful image dimensions without integer overflow.
    private static func validDimension(_ value: Int) -> Bool {
        value > 0 && value <= Int(Int32.max)
    }
}
