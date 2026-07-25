#!/usr/bin/env bash
# fetch-native.sh — pub.dev から取得したパッケージ向けに、ネイティブバイナリを
# ビルド時に自動ダウンロードする。
#
#   iOS   : voicevox_flutter.podspec の prepare_command から呼ばれる
#   Android: android/build.gradle の downloadVoicevoxNatives タスクから呼ばれる
#
# 使い方: fetch-native.sh <ios|android> <出力先ディレクトリ>
#
# リポジトリから直接使う(git 依存 / モノレポ開発)場合は、既に
# prepare-binaries.sh が同じ場所へ配置しているため何もしない(冪等)。
#
# Open JTalk 辞書はここでは取得しない。約100MBあるため、.vvm 音声モデルと
# 同じく実行時ダウンロード(lib/src/dictionary.dart)にしている。
set -euo pipefail

PLATFORM="${1:?usage: fetch-native.sh <ios|android> <dest-dir>}"
DEST="${2:?usage: fetch-native.sh <ios|android> <dest-dir>}"

# packages/core-native/VERSION と同期させること
VOICEVOX_CORE_VERSION="0.16.4"
VOICEVOX_ONNXRUNTIME_VERSION="1.17.3"

CORE_BASE="https://github.com/VOICEVOX/voicevox_core/releases/download/${VOICEVOX_CORE_VERSION}"
ORT_BASE="https://github.com/VOICEVOX/onnxruntime-builder/releases/download/voicevox_onnxruntime-${VOICEVOX_ONNXRUNTIME_VERSION}"

log() { echo "[voicevox_flutter] $*" >&2; }

fetch_and_extract() { # url dest_dir
  local url="$1" dest_dir="$2" tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  local archive="$tmp/$(basename "$url")"
  log "downloading $(basename "$url")"
  curl -fL --retry 3 --progress-bar -o "$archive" "$url"
  mkdir -p "$dest_dir"
  case "$archive" in
    *.zip) unzip -oq "$archive" -d "$dest_dir" ;;
    *.tgz|*.tar.gz) tar xzf "$archive" -C "$dest_dir" ;;
    *) log "unknown archive type: $archive"; return 1 ;;
  esac
}

case "$PLATFORM" in
  ios)
    # 既に配置済み(モノレポ開発時)なら何もしない
    if [[ -d "$DEST/voicevox_core.xcframework" && -d "$DEST/voicevox_onnxruntime.xcframework" ]]; then
      log "iOS frameworks already present, skipping download"
      exit 0
    fi
    mkdir -p "$DEST"
    fetch_and_extract "$CORE_BASE/voicevox_core-ios-xcframework-cpu-${VOICEVOX_CORE_VERSION}.zip" "$DEST"
    fetch_and_extract "$ORT_BASE/voicevox_onnxruntime-ios-xcframework-${VOICEVOX_ONNXRUNTIME_VERSION}.zip" "$DEST"

    # 公式フレームワークの CFBundleIdentifier にアンダースコアが含まれており
    # (jp.hiroshiba.voicevox.voicevox_onnxruntime)、Xcode 16+ の埋め込み検証で
    # 拒否されるためハイフンに修正する。
    find "$DEST" -name Info.plist -path '*.framework/*' | while read -r plist; do
      current="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null || true)"
      case "$current" in
        *_*)
          /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${current//_/-}" "$plist"
          log "normalized bundle id: $current -> ${current//_/-}"
          ;;
      esac
    done
    log "iOS frameworks ready in $DEST"
    ;;

  macos)
    if [[ -d "$DEST/voicevox_core.xcframework" && -d "$DEST/voicevox_onnxruntime.xcframework" ]]; then
      log "macOS frameworks already present, skipping download"
      exit 0
    fi
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$DEST"

    for arch_pair in "arm64:arm64" "x64:x86_64"; do
      core_arch="${arch_pair%%:*}"
      fetch_and_extract "$CORE_BASE/voicevox_core-osx-${core_arch}-${VOICEVOX_CORE_VERSION}.zip" "$tmp"
    done
    fetch_and_extract "$ORT_BASE/voicevox_onnxruntime-osx-arm64-${VOICEVOX_ONNXRUNTIME_VERSION}.tgz" "$tmp"
    fetch_and_extract "$ORT_BASE/voicevox_onnxruntime-osx-x86_64-${VOICEVOX_ONNXRUNTIME_VERSION}.tgz" "$tmp"

    # dylib を universal 化して .framework バンドルにし、xcframework へ包む
    # (xcframework は framework と library を混在できないため)
    make_macos_framework() { # name universal_dylib headers_dir out_dir
      local name="$1" dylib="$2" headers="$3" out="$4"
      local fw="$out/$name.framework"
      mkdir -p "$fw/Versions/A/Headers" "$fw/Versions/A/Resources"
      cp "$dylib" "$fw/Versions/A/$name"
      install_name_tool -id "@rpath/$name.framework/Versions/A/$name" "$fw/Versions/A/$name"
      [[ -n "$headers" && -d "$headers" ]] && cp -R "$headers/." "$fw/Versions/A/Headers/"
      cat > "$fw/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$name</string>
  <key>CFBundleIdentifier</key><string>jp.voicevox.${name//_/-}</string>
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

    lipo -create \
      "$tmp/voicevox_core-osx-arm64-${VOICEVOX_CORE_VERSION}/lib/libvoicevox_core.dylib" \
      "$tmp/voicevox_core-osx-x64-${VOICEVOX_CORE_VERSION}/lib/libvoicevox_core.dylib" \
      -output "$tmp/libvoicevox_core.dylib"
    make_macos_framework voicevox_core "$tmp/libvoicevox_core.dylib" \
      "$tmp/voicevox_core-osx-arm64-${VOICEVOX_CORE_VERSION}/include" "$tmp/core-fw"
    xcodebuild -create-xcframework \
      -framework "$tmp/core-fw/voicevox_core.framework" \
      -output "$DEST/voicevox_core.xcframework" >/dev/null

    lipo -create \
      "$tmp/voicevox_onnxruntime-osx-arm64-${VOICEVOX_ONNXRUNTIME_VERSION}/lib/libvoicevox_onnxruntime.${VOICEVOX_ONNXRUNTIME_VERSION}.dylib" \
      "$tmp/voicevox_onnxruntime-osx-x86_64-${VOICEVOX_ONNXRUNTIME_VERSION}/lib/libvoicevox_onnxruntime.${VOICEVOX_ONNXRUNTIME_VERSION}.dylib" \
      -output "$tmp/libvoicevox_onnxruntime.dylib"
    make_macos_framework voicevox_onnxruntime "$tmp/libvoicevox_onnxruntime.dylib" "" "$tmp/ort-fw"
    xcodebuild -create-xcframework \
      -framework "$tmp/ort-fw/voicevox_onnxruntime.framework" \
      -output "$DEST/voicevox_onnxruntime.xcframework" >/dev/null

    log "macOS frameworks ready in $DEST"
    ;;

  android)
    if [[ -f "$DEST/arm64-v8a/libvoicevox_core.so" && -f "$DEST/arm64-v8a/libc++_shared.so" ]]; then
      log "Android jniLibs already present, skipping download"
      exit 0
    fi
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$DEST/arm64-v8a" "$DEST/x86_64"

    fetch_and_extract "$CORE_BASE/voicevox_core-android-arm64-${VOICEVOX_CORE_VERSION}.zip" "$tmp"
    fetch_and_extract "$CORE_BASE/voicevox_core-android-x86_64-${VOICEVOX_CORE_VERSION}.zip" "$tmp"
    fetch_and_extract "$ORT_BASE/voicevox_onnxruntime-android-arm64-${VOICEVOX_ONNXRUNTIME_VERSION}.tgz" "$tmp"
    fetch_and_extract "$ORT_BASE/voicevox_onnxruntime-android-x64-${VOICEVOX_ONNXRUNTIME_VERSION}.tgz" "$tmp"

    cp "$tmp/voicevox_core-android-arm64-${VOICEVOX_CORE_VERSION}/lib/libvoicevox_core.so" "$DEST/arm64-v8a/"
    cp "$tmp/voicevox_core-android-x86_64-${VOICEVOX_CORE_VERSION}/lib/libvoicevox_core.so" "$DEST/x86_64/"
    cp "$tmp/voicevox_onnxruntime-android-arm64-${VOICEVOX_ONNXRUNTIME_VERSION}/lib/libvoicevox_onnxruntime.so" "$DEST/arm64-v8a/"
    cp "$tmp/voicevox_onnxruntime-android-x64-${VOICEVOX_ONNXRUNTIME_VERSION}/lib/libvoicevox_onnxruntime.so" "$DEST/x86_64/"

    # libvoicevox_core.so は libc++_shared.so に動的リンクしている。
    # NDK から取り出して同梱する(NDK は Flutter の Android ビルドに必須)。
    if [[ -n "${ANDROID_NDK_HOME:-}" ]]; then
      ndk_dir="$ANDROID_NDK_HOME"
    else
      # glob をクォート内に入れると展開されないため、変数展開後に評価する
      sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
      ndk_dir="$(ls -d "$sdk_root"/ndk/* 2>/dev/null | sort -V | tail -1 || true)"
    fi
    if [[ -z "$ndk_dir" || ! -d "$ndk_dir" ]]; then
      log "error: Android NDK not found (needed for libc++_shared.so)."
      log "       Set ANDROID_NDK_HOME or install the NDK via Android Studio."
      exit 1
    fi
    host="$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64"
    sysroot_libs="$ndk_dir/toolchains/llvm/prebuilt/$host/sysroot/usr/lib"
    cp "$sysroot_libs/aarch64-linux-android/libc++_shared.so" "$DEST/arm64-v8a/"
    cp "$sysroot_libs/x86_64-linux-android/libc++_shared.so" "$DEST/x86_64/"
    log "Android jniLibs ready in $DEST"
    ;;

  *)
    log "unknown platform: $PLATFORM (expected ios or android)"
    exit 1
    ;;
esac
