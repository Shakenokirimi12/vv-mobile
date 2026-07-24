#!/usr/bin/env bash
# prepare-binaries.sh — Flutter パッケージのビルドに必要な取得物を配置する。
#   1. iOS/macOS: 統合 xcframework(packages/swift/Binaries から流用)
#   2. Android: libvoicevox_core.so + libvoicevox_onnxruntime.so → jniLibs
#   3. assets: licenses.json + Open JTalk 辞書
# 事前に以下を実行しておくこと:
#   ../core-native/scripts/fetch-core.sh ios osx android
#   ../swift/scripts/prepare-binaries.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(dirname "$SCRIPT_DIR")"
CORE="$PKG_DIR/../core-native"
DIST="$CORE/dist"
SWIFT_BIN="$PKG_DIR/../swift/Binaries"

# shellcheck disable=SC1091
source "$CORE/VERSION"

[[ -d "$SWIFT_BIN/voicevox_core.xcframework" ]] || {
  echo "error: run ../swift/scripts/prepare-binaries.sh first" >&2
  exit 1
}
[[ -d "$DIST/android" ]] || {
  echo "error: run ../core-native/scripts/fetch-core.sh android first" >&2
  exit 1
}

# --- 1. iOS/macOS xcframework ---
for platform in ios macos; do
  fw="$PKG_DIR/$platform/Frameworks"
  rm -rf "$fw"
  mkdir -p "$fw"
  cp -R "$SWIFT_BIN/voicevox_core.xcframework" "$fw/"
  cp -R "$SWIFT_BIN/voicevox_onnxruntime.xcframework" "$fw/"
done

# --- 2. Android jniLibs ---
jni="$PKG_DIR/android/src/main/jniLibs"
rm -rf "$jni"
mkdir -p "$jni/arm64-v8a" "$jni/x86_64"
cp "$DIST/android/voicevox_core-android-arm64-${VOICEVOX_CORE_VERSION}/lib/libvoicevox_core.so" "$jni/arm64-v8a/"
cp "$DIST/android/voicevox_core-android-x86_64-${VOICEVOX_CORE_VERSION}/lib/libvoicevox_core.so" "$jni/x86_64/"
cp "$DIST/android/voicevox_onnxruntime-android-arm64-${VOICEVOX_ONNXRUNTIME_VERSION}/lib/libvoicevox_onnxruntime.so" "$jni/arm64-v8a/"
cp "$DIST/android/voicevox_onnxruntime-android-x64-${VOICEVOX_ONNXRUNTIME_VERSION}/lib/libvoicevox_onnxruntime.so" "$jni/x86_64/"

# --- 3. assets ---
rm -rf "$PKG_DIR/assets/open_jtalk_dic"
mkdir -p "$PKG_DIR/assets"
cp -R "$DIST/common/open_jtalk_dic_utf_8-${OPEN_JTALK_DICT_VERSION}" "$PKG_DIR/assets/open_jtalk_dic"
cp "$CORE/generated/licenses.json" "$PKG_DIR/assets/licenses.json"

echo "done."
