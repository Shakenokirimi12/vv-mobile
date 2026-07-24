// swift-tools-version: 5.9
import PackageDescription

// ビルド済みバイナリ(xcframework)は ../../scripts/prepare-binaries.sh が
// Frameworks/ に配置する。
let package = Package(
    name: "voicevox_flutter",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "voicevox-flutter", targets: ["voicevox_flutter"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "voicevox_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "voicevox_core_binary",
                "voicevox_onnxruntime_binary",
            ]
        ),
        .binaryTarget(
            name: "voicevox_core_binary",
            path: "Frameworks/voicevox_core.xcframework"
        ),
        .binaryTarget(
            name: "voicevox_onnxruntime_binary",
            path: "Frameworks/voicevox_onnxruntime.xcframework"
        ),
    ]
)
