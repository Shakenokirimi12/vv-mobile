// swift-tools-version: 5.9
// SwiftPM 公開タグ(swift-vX.Y.Z)専用の Package.swift。
import PackageDescription

let package = Package(
    name: "VoicevoxCore",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "VoicevoxCore", targets: ["VoicevoxCore"])
    ],
    targets: [
        .target(name: "CVoicevoxCore", path: "Sources/CVoicevoxCore"),
        .target(
            name: "VoicevoxCore",
            dependencies: ["CVoicevoxCore", "voicevox_core_binary", "voicevox_onnxruntime_binary"],
            path: "Sources/VoicevoxCore",
            resources: [.copy("Resources/licenses.json"), .copy("Resources/open_jtalk_dic")]
        ),
        .binaryTarget(
            name: "voicevox_core_binary",
            url: "https://github.com/Shakenokirimi12/vv-mobile/releases/download/swift-v0.1.0/voicevox_core.xcframework.zip",
            checksum: "b787c6852b9c756e5c4ab8d812507c0ef39f1e7a4af4e40584c68b272af2b9ca"
        ),
        .binaryTarget(
            name: "voicevox_onnxruntime_binary",
            url: "https://github.com/Shakenokirimi12/vv-mobile/releases/download/swift-v0.1.0/voicevox_onnxruntime.xcframework.zip",
            checksum: "c8744176cdf090a44a3cd2459e8ced7b531ba0e34d4f37dfe8d5129cc662aba8"
        ),
    ]
)
