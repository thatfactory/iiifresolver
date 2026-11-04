# Architecture

IIIFResolver owns discovery, metadata, image sizing, and downloads. Consumers own UI, preferred artists or movements, wallpaper selection, scheduling, long-term storage, and retry policy.

## Data flow

```text
Search -> artwork references + continuation
                  |
           HumanMadeObject + metadata
                  |
                shows
                  |
             VisualItem + image rights
                  |
          digitally_shown_by
                  |
             DigitalObject
                  |
             access_point
                  |
           IIIF service URL
                  |
              info.json
                  |
        capability-aware JPEG request
                  |
          validated local file
```

The provider follows exact returned identifiers, requests `_profile=la-framed`, and validates record identity/type. Artwork, visual, and digital identifiers are distinct. Multiple images remain selectable; duplicate services merge their rights in original order. Optional educational fields require no extra person/vocabulary fetches. Display attributions and qualifiers are preserved.

Creator attribution prefers Rijksmuseum's descriptive production statements classified as `300435416`, which include its display qualifiers. When an activity has no such statement, it uses localized `carried_out_by[].notation` names and visits component `part` activities recursively. Other production notes, including abstract notes classified as `300435417`, are not interpreted as creators. This is a Rijksmuseum mapping, not a generic inference about every Linked Art production description. The [provider search tutorial](https://data.rijksmuseum.nl/tutorials/search/) documents actor notations; current framed records also supply qualified display statements.

The Rijksmuseum adapter accepts its numeric persistent identifiers and documented search continuation URLs. It derives Micrio service URLs from the known whole-image access-point shape. The reusable IIIF client accepts arbitrary HTTPS Image API 3 service/information URLs and does not depend on a museum hostname. Unknown JSON fields are ignored; incompatible representations produce typed failures. Failed linked requests abort the detail operation instead of silently omitting images. Empty image arrays are valid.

## Images and files

The IIIF client validates profile, dimensions, capabilities, and limits. `.maximum` uses `full/max/0/default.jpg`. `.fit` chooses a no-upscale width whose rounded proportional height and area remain within bounds. Level-zero services without width scaling use advertised discrete sizes.

URLSession downloads to a temporary file. Validation checks HTTP 200, JPEG content type, ImageIO format/dimensions/completion, and a bounded thumbnail decode without allocating a full-resolution bitmap. The validated file is copied to a unique staging file beside the destination, then published through a hard link that atomically fails if a destination already exists. Transport and staging files are removed on ordinary success/failure/cancellation paths. A process crash can leave a hidden `.iiifresolver-*.tmp` staging file; the package does not scan or delete unrelated consumer directories later.

The caller creates the destination directory and owns the result. Filesystems without hard links return `ResolverError.fileSystem`. Cancellation is checked after network suspension and before publication. Publication is the commit point: a subsequent cancellation cannot turn the completed write into a reported failure.

## Networking and concurrency

`HTTPTransport` is the internal injectable boundary. Production uses `HTTPRequest`, `HTTPResponse`, typed methods/statuses/headers, and HTTPTypesFoundation's URLSession data/download overloads. There is no parallel HTTP model, custom transport, TLS exception, credential store, or retry loop. `ResolverError.httpResponse` retains the typed status. URLSession owns native transport security.

Public values and clients are `Sendable`; public asynchronous operations use `@concurrent` without imposing MainActor isolation. Clients hold no mutable cache. Separate calls are independent; linked records within an artwork resolve sequentially. Tests inject transports and event sinks without changing global URLSession state.

## Dependencies

| Dependency | Requirement | Target role |
|---|---|---|
| [AppLogger](https://github.com/thatfactory/applogger) | From 1.1.2, within major 1 | Library diagnostics and logging tests. |
| [swift-http-types](https://github.com/apple/swift-http-types) | From 1.8.0, within major 1 | HTTPTypes and HTTPTypesFoundation in the library and networking tests; URLSession remains the transport. |
| [swift-docc-plugin](https://github.com/swiftlang/swift-docc-plugin) | From 1.5.0, within major 1 | Documentation tooling only; no runtime linkage. |

`Package.resolved` records validated versions. Review updates intentionally and rerun affected checks. HTTPTypes/HTTPTypesFoundation use agent-guidelines 0.0.45's networking standing approval, with no separate consumer exception. The unmodified tagged AgentGuidelines subtree supplies policy and validation tools.

## Diagnostics

The canonical emoji is 🔎 and subsystem is `com.thatfactory.iiifresolver`. `ResolverLogger` owns AppLogger calls and the `resolution`/`download` categories. Each asynchronous search, artwork resolution, service resolution, and download emits one terminal success, failure, or cancellation event. Failures contain fixed reason names and safe HTTP/URL error codes. Events omit query text, record IDs, URLs, local paths, metadata, response bodies, and image bytes. No-next-page returns, pure models, and request sizing deliberately remain silent.

Tests verify prefixes, categories, severity, privacy, fields, and single emission through an injected sink, without querying persisted unified logs.

## Protocol references

- [Rijksmuseum search](https://data.rijksmuseum.nl/docs/search).
- [Linked-data resolver](https://data.rijksmuseum.nl/docs/http).
- [Rijksmuseum image discovery](https://data.rijksmuseum.nl/docs/iiif/image).
- [IIIF Image API 3](https://iiif.io/api/image/3.0/).
