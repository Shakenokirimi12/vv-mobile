#!/usr/bin/env bash
# prepare-binaries.sh — Flutter パッケージのビルドに必要な取得物を配置する。
#   1. iOS/macOS: 統合 xcframework(packages/swift/Binaries から流用)
#   2. Android: libvoicevox_core.so + libvoicevox_onnxruntime.so → jniLibs
#   3. assets: licenses.json
# Open JTalk 辞書はここでは配置しない。0.1.1 で Flutter アセットから外し、
# 初回起動時のダウンロード(lib/src/dictionary.dart)に移したため。
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

# libvoicevox_core.so は libc++_shared.so に動的リンクしている。
# Flutter プラグインは NDK ビルドを行わず自動同梱されないため、NDK から取り出して同梱する。
ndk_dir="$(ls -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/ndk/* 2>/dev/null | sort -V | tail -1)"
[[ -n "$ndk_dir" ]] || { echo "error: Android NDK not found (needed for libc++_shared.so)" >&2; exit 1; }
sysroot_libs="$ndk_dir/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib"
cp "$sysroot_libs/aarch64-linux-android/libc++_shared.so" "$jni/arm64-v8a/"
cp "$sysroot_libs/x86_64-linux-android/libc++_shared.so" "$jni/x86_64/"

# --- 3. assets ---
# 辞書(約100MB)は pubspec の assets から外したのでコピーしない。残っていると
# 参照されないまま 100MB を消費するだけなので、古い配置は掃除しておく。
rm -rf "$PKG_DIR/assets/open_jtalk_dic"
mkdir -p "$PKG_DIR/assets"
cp "$CORE/generated/licenses.json" "$PKG_DIR/assets/licenses.json"

echo "done."
