#!/usr/bin/env bash
# prepare-sources.sh — RN パッケージに Swift/Kotlin 実装・バイナリ・リソースを
# packages/swift・packages/android から複製して配置する(単一の実装を共有する)。
# 事前に以下を実行しておくこと:
#   ../core-native/scripts/fetch-core.sh ios osx android
#   ../swift/scripts/prepare-binaries.sh
#   ../android/scripts/prepare-binaries.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(dirname "$SCRIPT_DIR")"
CORE="$PKG_DIR/../core-native"
SWIFT_PKG="$PKG_DIR/../swift"
ANDROID_PKG="$PKG_DIR/../android"

# shellcheck disable=SC1091
source "$CORE/VERSION"

[[ -d "$SWIFT_PKG/Binaries/voicevox_core.xcframework" ]] || {
  echo "error: run ../swift/scripts/prepare-binaries.sh first" >&2
  exit 1
}

# --- iOS: VoicevoxCore Swift 実装 + CVoicevoxCore ヘッダ ---
ios_vc="$PKG_DIR/ios/VoicevoxCore"
rm -rf "$ios_vc"
mkdir -p "$ios_vc/CVoicevoxCore"
cp "$SWIFT_PKG"/Sources/VoicevoxCore/*.swift "$ios_vc/"
cp -R "$SWIFT_PKG/Sources/CVoicevoxCore/include" "$ios_vc/CVoicevoxCore/include"

# CocoaPods ビルドでは SwiftPM の Bundle.module が生成されないため、
# リソースバンドル(RNVoicevoxResources)へ解決するシムを追加する。
cat > "$ios_vc/BundleModuleShim.swift" <<'EOF'
// CocoaPods ビルド用: SwiftPM の Bundle.module 相当を
// RNVoicevoxResources.bundle に解決する。
#if !SWIFT_PACKAGE
import Foundation

extension Bundle {
    static let module: Bundle = {
        let container = Bundle(for: BundleToken.self)
        if let url = container.url(forResource: "RNVoicevoxResources", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return container
    }()
}

private final class BundleToken {}
#endif
EOF

# --- iOS: xcframework とリソース ---
rm -rf "$PKG_DIR/ios/Frameworks" "$PKG_DIR/ios/Resources"
mkdir -p "$PKG_DIR/ios/Frameworks" "$PKG_DIR/ios/Resources"
cp -R "$SWIFT_PKG/Binaries/voicevox_core.xcframework" "$PKG_DIR/ios/Frameworks/"
cp -R "$SWIFT_PKG/Binaries/voicevox_onnxruntime.xcframework" "$PKG_DIR/ios/Frameworks/"
cp "$CORE/generated/licenses.json" "$PKG_DIR/ios/Resources/licenses.json"
cp -R "$CORE/dist/common/open_jtalk_dic_utf_8-${OPEN_JTALK_DICT_VERSION}" "$PKG_DIR/ios/Resources/open_jtalk_dic"

# --- Android: Kotlin 実装・assets・jniLibs・local-maven ---
vendored="$PKG_DIR/android/vendored"
rm -rf "$vendored"
mkdir -p "$vendored"
cp -R "$ANDROID_PKG/lib/src/main/kotlin" "$vendored/kotlin"
cp -R "$ANDROID_PKG/lib/src/main/assets" "$vendored/assets"
cp -R "$ANDROID_PKG/lib/src/main/jniLibs" "$vendored/jniLibs"
cp -R "$ANDROID_PKG/local-maven" "$vendored/local-maven"

echo "done."
