import Foundation

/// Pure request sizing that respects protocol capabilities, aspect ratio, and service limits.
enum IIIFRequestBuilder {
    /// Builds a whole-image, unrotated, default-quality JPEG URL.
    static func request(service: IIIFImageService, size: IIIFImageSize) throws -> IIIFImageRequest {
        let bounds: ImageDimensions
        let sizePath: String
        switch size {
        case .maximum:
            bounds = service.maximumDimensions
            sizePath = "max"
        case .fit(let width, let height):
            guard width > 0, height > 0 else { throw ResolverError.unsupportedSize }
            bounds = ImageDimensions(
                width: min(width, service.maximumDimensions.width),
                height: min(height, service.maximumDimensions.height)
            )
            if service.supportsWidth {
                sizePath = try widthRequest(service: service, bounds: bounds)
            } else {
                let sizes = service.sizes.filter {
                    $0.width <= bounds.width && $0.height <= bounds.height
                }
                guard
                    let selected = sizes.max(by: {
                        Double($0.width) * Double($0.height) < Double($1.width) * Double($1.height)
                    })
                else { throw ResolverError.unsupportedSize }
                sizePath = "\(selected.width),\(selected.height)"
            }
        }
        let url = service.id.appendingPathComponent("full").appendingPathComponent(sizePath)
            .appendingPathComponent("0").appendingPathComponent("default.jpg")
        return IIIFImageRequest(url: url, maximumDimensions: bounds, maximumPixelArea: service.maximumPixelArea)
    }

    // MARK: - Private

    /// Chooses a width whose rounded-up proportional height remains within all bounds.
    private static func widthRequest(service: IIIFImageService, bounds: ImageDimensions) throws -> String {
        let originalWidth = Double(service.dimensions.width)
        let originalHeight = Double(service.dimensions.height)
        var scale = min(Double(bounds.width) / originalWidth, Double(bounds.height) / originalHeight)
        if let area = service.maximumPixelArea {
            scale = min(scale, sqrt(Double(area) / originalWidth / originalHeight))
        }
        var width = Int(floor(originalWidth * scale))
        while width > 0 {
            let height = ceil(Double(width) * originalHeight / originalWidth)
            if height <= Double(bounds.height),
                service.maximumPixelArea.map({ Double(width) * height <= Double($0) }) ?? true
            {
                return "\(width),"
            }
            width -= 1
        }
        throw ResolverError.unsupportedSize
    }
}
