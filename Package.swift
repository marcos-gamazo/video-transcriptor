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

// Vosk (Kaldi) se enlaza como dylib universal2 (x86_64 + arm64) vendido en
// `Vendor/vosk`. El header se expone como módulo C `CVosk`. El deploy se hace
// con install name `@rpath/libvosk.dylib` para embeber en el .app (Fase 11).
let voskDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Vendor/vosk", isDirectory: true)
    .path

let voskLinkerSettings: [LinkerSetting] = [
    .unsafeFlags([
        "-L", voskDir,
        "-lvosk",
        // Ruta del Vendor durante desarrollo (el binario corre desde .build).
        "-Xlinker", "-rpath", "-Xlinker", voskDir,
        // En la app empaquetada el dylib se embebe en Contents/Frameworks.
        "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"
    ])
]

let package = Package(
    name: "Transcriptor",
    platforms: [
        .macOS(.v11)
    ],
    targets: [
        .target(
            name: "CVosk",
            path: "Sources/CVosk",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "Transcriptor",
            dependencies: ["CVosk"],
            path: "Sources/Transcriptor",
            linkerSettings: voskLinkerSettings
        ),
        .testTarget(
            name: "TranscriptorTests",
            dependencies: [
                "Transcriptor",
                "CVosk"
            ],
            path: "Tests/TranscriptorTests",
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: testTargetFlags,
            linkerSettings: voskLinkerSettings
        )
    ]
)