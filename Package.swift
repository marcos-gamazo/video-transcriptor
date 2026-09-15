// swift-tools-version:6.2
import Foundation
import PackageDescription

// Swift Testing del toolchain local (swift.org Homebrew) exige un deployment
// mínimo de macOS 26 para compilar los tests. En CI (Swift de Xcode) y en otras
// máquinas se compila para la versión del host. Se configura por entorno:
//
//   SWIFT_TEST_TARGET=arm64-apple-macosx26.0  # este Mac (toolchain 6.3)
//   SWIFT_TEST_TARGET=arm64-apple-macosx15.0  # runner GitHub Actions
let testTargetFlags: [SwiftSetting] = {
    guard let target = ProcessInfo.processInfo.environment["SWIFT_TEST_TARGET"],
          !target.isEmpty else { return [] }
    return [.unsafeFlags(["-target", target])]
}()

let package = Package(
    name: "Transcriptor",
    platforms: [
        .macOS(.v11)
    ],
    targets: [
        .executableTarget(
            name: "Transcriptor",
            path: "Sources/Transcriptor"
        ),
        .testTarget(
            name: "TranscriptorTests",
            dependencies: [
                "Transcriptor"
            ],
            path: "Tests/TranscriptorTests",
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: testTargetFlags
        )
    ]
)