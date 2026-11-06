# Build and CI

Use the active Xcode/Swift toolchain with Swift tools 6.4 and Swift 6 language mode. Every library/test target uses the shared warnings-as-errors and upcoming-feature baseline. Swift 6 owns complete concurrency checking; the package does not impose MainActor isolation.

CI follows the shared [runner toolchain policy](../AgentGuidelines/Guidelines/CICD.md#runner-toolchain): respect inherited `DEVELOPER_DIR` or the configured Xcode selection, report the actual toolchain, and let builds and tests establish compatibility. No exact toolchain exception applies. The last validated baseline is Xcode 27.2 (27B52) and Swift 6.4.2.

## Local validation

```sh
echo "Developer directory: ${DEVELOPER_DIR:-$(xcode-select -p)}"
xcodebuild -version
xcrun swiftc --version
AgentGuidelines/Scripts/swift_format.sh format-and-lint Package.swift Sources Tests
AgentGuidelines/Scripts/validate_consumer_setup.swift
swift package resolve
swift test
swift build -c release
```

Formatting must succeed before build/test. SwiftPM does not rewrite sources. Tests use controlled responses, synthetic Linked Art fixtures based on current public wire shapes, and JPEGs generated in isolated temporary directories. No external service, account, API key, UI, or persistent log store is required.

Compile other supported platforms sequentially on the shared machine:

```sh
for platform in iOS tvOS watchOS visionOS; do
  xcodebuild -scheme IIIFResolver -configuration Release \
    -destination "generic/platform=$platform" \
    -derivedDataPath .build/platforms build CODE_SIGNING_ALLOWED=NO
done
```

Generate documentation:

```sh
swift package --allow-writing-to-directory .build/documentation generate-documentation \
  --target IIIFResolver --disable-indexing --output-path .build/documentation \
  --transform-for-static-hosting --hosting-base-path iiifresolver
```

## Live verification

```sh
IIIFRESOLVER_LIVE_TESTS=1 swift test --filter LiveIntegrationTests
```

The opt-in test searches for Van Gogh drawings, resolves the first artwork and image, and downloads a JPEG bounded to 256 pixels into an automatically cleaned directory. It uses the package's native URLSession transport. This establishes the provider contract at that moment, not ongoing service availability or every artwork. Ordinary CI leaves it disabled. Artwise integration and wallpaper behavior require separate consumer validation.

## Runner labels:

Apple jobs use `[self-hosted, macOS, ARM64]` with an active Xcode installation and the required iOS/tvOS/watchOS/visionOS SDKs installed. Tests run on macOS; other platforms receive Release compile checks. Generic Pages deployment uses `ubuntu-latest`. Do not change global Xcode selection or clear shared caches.

PR/main workflows run the same validation steps: consumer integration, strict nonmutating lint, locked resolution, deterministic tests, Release build, all-platform compilation, and DocC. Draft PRs run validation. Fork code is skipped on the persistent self-hosted runner; maintainers must review it and arrange isolated validation before accepting external contributions.

## Release

Run `agent-guidelines-audit` before preparing the release PR. Open the validated release PR ready for its initial automatic Codex P0/P1 review. Record the actual reviewed head, locally verify any remediation-only delta, and require green current-head checks before an authorized squash merge. Do not request manual reviews without owner instruction.

After merge, publish matching semantic-version tag and GitHub release. The release workflow repeats validation, generates DocC with the `iiifresolver` hosting base, copies the root redirect, uploads, and deploys GitHub Pages. Documentation publishing never precedes the reviewed release. Register the package and canonical 🔎 emoji in the Swift Package Collection, then verify clean remote resolution and documentation availability.
