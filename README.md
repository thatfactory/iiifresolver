<p align="center">
  <a href="https://developer.apple.com/swift/"><img alt="Swift Version" src="https://img.shields.io/badge/Swift-6.4.2-ea7a50.svg?logo=swift&logoColor=white"></a>
  <a href="https://developer.apple.com/xcode/"><img alt="Xcode Version" src="https://img.shields.io/badge/Xcode-27.2-50ace8.svg?logo=xcode&logoColor=white"></a>
  <img alt="Platforms" src="https://img.shields.io/badge/Apple_platforms-26%2B-lightgrey.svg?logo=apple&logoColor=white">
  <a href="https://developer.apple.com/documentation/xcode/swift-packages"><img alt="SPM" src="https://img.shields.io/badge/SPM-ready-b68f6a.svg?logo=gitlfs&logoColor=white"></a>
  <a href="https://thatfactory.github.io/iiifresolver/documentation/iiifresolver/"><img alt="DocC" src="https://img.shields.io/badge/DocC-documentation-0288D1.svg?logo=bookstack&logoColor=white"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/License-MIT-67ac5b.svg?logo=googledocs&logoColor=white"></a>
  <a href="https://github.com/thatfactory/iiifresolver/commits/main/"><img alt="Updated" src="https://img.shields.io/github/last-commit/thatfactory/iiifresolver?label=Updated&logo=convertio&logoColor=white"></a>
  <a href="https://github.com/thatfactory/iiifresolver/releases"><img alt="Revision" src="https://img.shields.io/github/v/release/thatfactory/iiifresolver?label=Revision&logo=gitbook&logoColor=white"></a>
  <a href="https://github.com/thatfactory/iiifresolver/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/thatfactory/iiifresolver/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/thatfactory/iiifresolver/actions/workflows/release.yml"><img alt="Release" src="https://github.com/thatfactory/iiifresolver/actions/workflows/release.yml/badge.svg"></a>
</p>

# IIIFResolver 🔎

**The tripe-I-eff resolver** discovers museum artworks and resolves downloadable IIIF images. Its name refers to the International Image Interoperability Framework (IIIF, pronounced “triple-eye-eff”).

Rijksmuseum is the first discovery provider. The independent IIIF Image API 3 client also resolves other HTTPS image services directly. Both clients are UI-independent and use Swift concurrency with native, typed HTTP networking.

## Requirements and integration

Xcode 27.2 (27B52), Swift 6.4.2, and iOS, macOS, tvOS, watchOS, or visionOS 26+. The manifest uses Swift tools 6.4 and Swift 6 language mode.

```swift
.package(url: "https://github.com/thatfactory/iiifresolver.git", from: "0.1.0")
```

Add `.product(name: "IIIFResolver", package: "iiifresolver")` to your target dependencies.

## Search, resolve, download

```swift
import Foundation
import IIIFResolver

func downloadFirstArtwork(to destination: URL) async throws {
    let museum = RijksmuseumClient()
    let page = try await museum.search(
        RijksmuseumQuery(creators: ["vincent van gogh"], objectType: "drawing")
    )
    guard let reference = page.artworks.first else { return }
    let artwork = try await museum.artwork(for: reference)
    guard let image = artwork.images.first else { return }

    let client = IIIFImageClient()
    let service = try await client.resolve(image.serviceURL)
    let request = try client.imageRequest(
        for: service, size: .fit(width: 3840, height: 2160)
    )
    _ = try await client.download(request, to: destination)
}
```

Search returns one provider-sized page of references. Use `museum.nextPage(after: page)` for the next page; nil means the collection has ended. Empty filters are omitted and `imageAvailable` defaults to true. Filters include creators, title, description, object type, materials, techniques, creation date, and object number. Rijksmuseum does not require an API key.

Artwork details include available titles, artist attribution, display dates, descriptions, materials, techniques, catalogue links, and image representations. Text retains language vocabulary identifiers; compact vocabulary language tags become `urn:ietf:bcp:47:<tag>`. Museum display statements preserve attribution qualifiers; when absent, named production actors supply the attribution. Unrelated production notes are excluded. Missing optional metadata stays absent. Image rights are separate from catalogue metadata licensing.

Use `request.url` for previews or `.maximum` for the maximum **permitted by the service**, which may be below the original resolution. Bounded requests preserve aspect ratio and respect advertised capabilities, dimensions, and pixel-area limits. Static level-zero services use their listed sizes and reject bounds for which none fit.

The destination's parent must exist and support hard links, as normal Apple app storage does. Downloads validate the response and JPEG, stage on the destination volume, and publish without replacing existing files. The caller owns successful downloads. Failure and cancellation before publication remove partial files; after publication, success is returned. `ResolverError` distinguishes failures; cancellation becomes `CancellationError`.

## Boundaries

Version 0.1 supports IIIF Image API 3, whole-image JPEGs, and the current Rijksmuseum framed Linked Art/Micrio flow. Presentation manifests, Image API 2, tile assembly, cropping, authentication flows, automatic retries, persistent caches, wallpaper scheduling, UI, and additional museum search adapters are outside this release. Search never eagerly downloads images. A failed linked request throws rather than silently omitting image representations.

## Development

See [Architecture](Documentation/Architecture.md) for data flow, dependencies, and diagnostics, and [Build and CI](Documentation/BuildAndCI.md) for tests and release checks. Public API documentation is published through [DocC](https://thatfactory.github.io/iiifresolver/documentation/iiifresolver/).
