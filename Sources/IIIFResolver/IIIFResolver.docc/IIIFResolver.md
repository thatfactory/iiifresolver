# ``IIIFResolver``

Discover museum artworks and resolve downloadable IIIF images.

## Overview

IIIFResolver 🔎 — the tripe-I-eff resolver — separates museum discovery from reusable IIIF Image API 3 delivery. ``RijksmuseumClient`` owns search and Linked Art traversal. ``IIIFImageClient`` resolves service information, prepares JPEG requests, and publishes validated files.

Search returns references without downloading images. Fetch one artwork's details to obtain educational metadata and selectable image representations. Text preserves language identities and attribution qualifiers. Image rights remain distinct from catalogue licensing.

```swift
let museum = RijksmuseumClient()
let page = try await museum.search(RijksmuseumQuery(creators: ["vincent van gogh"]))
if let reference = page.artworks.first {
    let artwork = try await museum.artwork(for: reference)
    if let image = artwork.images.first {
        let client = IIIFImageClient()
        let service = try await client.resolve(image.serviceURL)
        let preview = try client.imageRequest(for: service, size: .fit(width: 512, height: 512))
        // Use preview.url in your presentation layer or download it to a caller-owned file.
    }
}
```

Maximum size means the service's maximum permitted output, not necessarily original resolution. Bounded requests preserve aspect ratio and never upscale. Static services use advertised sizes or throw when none fit.

Destinations must be new file URLs in existing directories with hard-link support. Downloads validate HTTP status, media type, image content, dimensions, and pixel area. Failure and cancellation clean up temporary files before publication. Publication never overwrites an existing file; after it succeeds, the caller owns the file.

Version 0.1 supports whole-image JPEGs and Image API 3. Presentation manifests, Image API 2, caching, automatic retries, wallpaper scheduling, and UI are outside the current contract.

## Topics

### Discover artworks

- ``RijksmuseumClient``
- ``RijksmuseumQuery``
- ``RijksmuseumPage``
- ``ArtworkReference``
- ``Artwork``
- ``ArtworkText``
- ``ArtworkImage``
- ``ArtworkRights``

### Resolve and download images

- ``IIIFImageClient``
- ``IIIFImageService``
- ``IIIFImageRequest``
- ``IIIFImageSize``
- ``ImageDimensions``
- ``ImageDownload``
- ``ResolverError``
