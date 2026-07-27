// swift-tools-version: 5.9
// SwiftPM は Package.swift をリポジトリの**ルート**からしか読まないため、
// 外部から `https://github.com/Shakenokirimi12/vv-mobile` を依存に指定できるよう
// ここにマニフェストを置く。ソースの実体は packages/swift/ にある。
//
// モノレポ内での開発(バイナリをローカルに置いて `swift build` する)には
// packages/swift/Package.swift を使う。こちらは常にリリース済みの
// xcframework を URL + checksum で取得する。
import PackageDescription

let binaryBaseURL =
    "https://github.com/Shakenokirimi12/vv-mobile/releases/download/swift-v0.1.0"

let package = Package(
    name: "VoicevoxCore",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "VoicevoxCore", targets: ["VoicevoxCore"])
    ],
    targets: [
        .target(
            name: "CVoicevoxCore",
            path: "packages/swift/Sources/CVoicevoxCore"
        ),
        .target(
            name: "VoicevoxCore",
            dependencies: ["CVoicevoxCore", "voicevox_core_binary", "voicevox_onnxruntime_binary"],
            path: "packages/swift/Sources/VoicevoxCore",
            resources: [
                .copy("Resources/licenses.json"),
                .copy("Resources/open_jtalk_dic"),
            ]
        ),
        .binaryTarget(
            name: "voicevox_core_binary",
            url: "\(binaryBaseURL)/voicevox_core.xcframework.zip",
            checksum: "b787c6852b9c756e5c4ab8d812507c0ef39f1e7a4af4e40584c68b272af2b9ca"
        ),
        .binaryTarget(
            name: "voicevox_onnxruntime_binary",
            url: "\(binaryBaseURL)/voicevox_onnxruntime.xcframework.zip",
            checksum: "c8744176cdf090a44a3cd2459e8ced7b531ba0e34d4f37dfe8d5129cc662aba8"
        ),
    ]
)
