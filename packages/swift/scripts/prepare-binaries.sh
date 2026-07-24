#!/usr/bin/env bash
# prepare-binaries.sh — core-native の取得物から SwiftPM 用の
# xcframework(iOS + macOS 統合)と同梱リソースを配置する。
# 事前に ../core-native/scripts/fetch-core.sh ios osx を実行しておくこと。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$(dirname "$SCRIPT_DIR")"
DIST="$PKG_DIR/../core-native/dist"
BIN="$PKG_DIR/Binaries"
TMP="$BIN/tmp"

# shellcheck disable=SC1091
source "$PKG_DIR/../core-native/VERSION"

[[ -d "$DIST/ios/voicevox_core.xcframework" ]] || {
  echo "error: run ../core-native/scripts/fetch-core.sh ios osx first" >&2
  exit 1
}

rm -rf "$BIN"
mkdir -p "$TMP"

# dylib から macOS 用 .framework バンドルを組み立てる
# (xcframework は framework と library を混在できないため、iOS 側に合わせて
#  macOS も framework 形式にする)
make_macos_framework() { # name universal_dylib headers_dir out_dir
  local name="$1" dylib="$2" headers="$3" out="$4"
  local fw="$out/$name.framework"
  mkdir -p "$fw/Versions/A/Headers" "$fw/Versions/A/Resources"
  cp "$dylib" "$fw/Versions/A/$name"
  install_name_tool -id "@rpath/$name.framework/Versions/A/$name" "$fw/Versions/A/$name"
  if [[ -n "$headers" && -d "$headers" ]]; then
    cp -R "$headers/." "$fw/Versions/A/Headers/"
  fi
  cat > "$fw/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$name</string>
  <key>CFBundleIdentifier</key><string>jp.voicevox.$name</string>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>${VOICEVOX_CORE_VERSION}</string>
  <key>CFBundleVersion</key><string>${VOICEVOX_CORE_VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST
  ln -s A "$fw/Versions/Current"
  ln -s Versions/Current/"$name" "$fw/$name"
  ln -s Versions/Current/Headers "$fw/Headers"
  ln -s Versions/Current/Resources "$fw/Resources"
}

# --- voicevox_core ---
core_ios="$DIST/ios/voicevox_core.xcframework"
core_osx_arm="$DIST/osx/voicevox_core-osx-arm64-${VOICEVOX_CORE_VERSION}"
core_osx_x64="$DIST/osx/voicevox_core-osx-x64-${VOICEVOX_CORE_VERSION}"

lipo -create \
  "$core_osx_arm/lib/libvoicevox_core.dylib" \
  "$core_osx_x64/lib/libvoicevox_core.dylib" \
  -output "$TMP/libvoicevox_core.dylib"
make_macos_framework voicevox_core "$TMP/libvoicevox_core.dylib" "$core_osx_arm/include" "$TMP/core-macos"

xcodebuild -create-xcframework \
  -framework "$core_ios/ios-arm64/voicevox_core.framework" \
  -framework "$core_ios/ios-arm64_x86_64-simulator/voicevox_core.framework" \
  -framework "$TMP/core-macos/voicevox_core.framework" \
  -output "$BIN/voicevox_core.xcframework"

# --- voicevox_onnxruntime ---
ort_ios="$DIST/ios/voicevox_onnxruntime.xcframework"
ort_osx_arm="$DIST/osx/voicevox_onnxruntime-osx-arm64-${VOICEVOX_ONNXRUNTIME_VERSION}"
ort_osx_x64="$DIST/osx/voicevox_onnxruntime-osx-x86_64-${VOICEVOX_ONNXRUNTIME_VERSION}"

lipo -create \
  "$ort_osx_arm/lib/libvoicevox_onnxruntime.${VOICEVOX_ONNXRUNTIME_VERSION}.dylib" \
  "$ort_osx_x64/lib/libvoicevox_onnxruntime.${VOICEVOX_ONNXRUNTIME_VERSION}.dylib" \
  -output "$TMP/libvoicevox_onnxruntime.dylib"
make_macos_framework voicevox_onnxruntime "$TMP/libvoicevox_onnxruntime.dylib" "" "$TMP/ort-macos"

xcodebuild -create-xcframework \
  -framework "$ort_ios/ios-arm64/voicevox_onnxruntime.framework" \
  -framework "$ort_ios/ios-arm64_x86_64-simulator/voicevox_onnxruntime.framework" \
  -framework "$TMP/ort-macos/voicevox_onnxruntime.framework" \
  -output "$BIN/voicevox_onnxruntime.xcframework"

rm -rf "$TMP"

# --- Open JTalk 辞書をリソースとして配置 ---
dict_src="$DIST/common/open_jtalk_dic_utf_8-${OPEN_JTALK_DICT_VERSION}"
dict_dst="$PKG_DIR/Sources/VoicevoxCore/Resources/open_jtalk_dic"
rm -rf "$dict_dst"
cp -R "$dict_src" "$dict_dst"

echo "done:"
ls "$BIN"
