// swift-tools-version:6.2
import PackageDescription

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
            swiftSettings: [
                // El Swift Testing de la toolchain 6.3 requiere macOS 26;
                // el producto/ejecutable sigue compilando para macOS 11.
                .unsafeFlags(["-target", "arm64-apple-macosx26.0"])
            ]
        )
    ]
)