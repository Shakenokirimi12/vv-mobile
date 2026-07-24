// swift-tools-version: 5.9
import PackageDescription
import Foundation

// ビルド済みバイナリ(xcframework)は scripts/prepare-binaries.sh が
// Binaries/ に配置する。リリース時は CI が URL + checksum に書き換える。
let binariesDir = "Binaries"
let hasBinaries = FileManager.default.fileExists(
    atPath: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("\(binariesDir)/voicevox_core.xcframework").path
)

var targets: [Target] = [
    .target(
        name: "CVoicevoxCore",
        path: "Sources/CVoicevoxCore"
    ),
    .target(
        name: "VoicevoxCore",
        dependencies: hasBinaries
            ? ["CVoicevoxCore", "voicevox_core_binary", "voicevox_onnxruntime_binary"]
            : ["CVoicevoxCore"],
        path: "Sources/VoicevoxCore",
        resources: [
            .copy("Resources/licenses.json"),
            .copy("Resources/open_jtalk_dic"),
        ]
    ),
    .testTarget(
        name: "VoicevoxCoreTests",
        dependencies: ["VoicevoxCore"],
        path: "Tests/VoicevoxCoreTests"
    ),
]

if hasBinaries {
    targets += [
        .binaryTarget(name: "voicevox_core_binary", path: "\(binariesDir)/voicevox_core.xcframework"),
        .binaryTarget(name: "voicevox_onnxruntime_binary", path: "\(binariesDir)/voicevox_onnxruntime.xcframework"),
    ]
}

let package = Package(
    name: "VoicevoxCore",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "VoicevoxCore", targets: ["VoicevoxCore"])
    ],
    targets: targets
)
