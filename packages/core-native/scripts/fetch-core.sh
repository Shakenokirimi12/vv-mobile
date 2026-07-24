#!/usr/bin/env bash
# fetch-core.sh — VOICEVOX CORE / ONNX Runtime / Open JTalk 辞書の公式ビルド済み
# アーティファクトを取得・検証して packages/core-native/dist/ に展開する。
#
# 使い方:
#   ./fetch-core.sh                 # 全プラットフォーム取得
#   ./fetch-core.sh ios android     # 指定プラットフォームのみ
#   UPDATE_CHECKSUMS=1 ./fetch-core.sh   # checksums.txt を再生成
#
# 対応プラットフォームキー:
#   ios / android / osx / linux / windows
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$ROOT_DIR/dist"
CACHE_DIR="$ROOT_DIR/.cache"
CHECKSUMS="$ROOT_DIR/checksums.txt"

# shellcheck disable=SC1091
source "$ROOT_DIR/VERSION"

CORE_BASE="https://github.com/VOICEVOX/voicevox_core/releases/download/${VOICEVOX_CORE_VERSION}"
ORT_BASE="https://github.com/VOICEVOX/onnxruntime-builder/releases/download/voicevox_onnxruntime-${VOICEVOX_ONNXRUNTIME_VERSION}"
DICT_URL="https://downloads.sourceforge.net/open-jtalk/open_jtalk_dic_utf_8-${OPEN_JTALK_DICT_VERSION}.tar.gz"

# platform key -> "core資産名..." / "onnxruntime資産名..."
core_assets() {
  case "$1" in
    ios)     echo "voicevox_core-ios-xcframework-cpu-${VOICEVOX_CORE_VERSION}.zip" ;;
    android) echo "voicevox_core-android-arm64-${VOICEVOX_CORE_VERSION}.zip voicevox_core-android-x86_64-${VOICEVOX_CORE_VERSION}.zip" ;;
    osx)     echo "voicevox_core-osx-arm64-${VOICEVOX_CORE_VERSION}.zip voicevox_core-osx-x64-${VOICEVOX_CORE_VERSION}.zip" ;;
    linux)   echo "voicevox_core-linux-x64-${VOICEVOX_CORE_VERSION}.zip voicevox_core-linux-arm64-${VOICEVOX_CORE_VERSION}.zip" ;;
    windows) echo "voicevox_core-windows-x64-${VOICEVOX_CORE_VERSION}.zip voicevox_core-windows-x86-${VOICEVOX_CORE_VERSION}.zip" ;;
    *) echo "unknown platform: $1" >&2; return 1 ;;
  esac
}

ort_assets() {
  case "$1" in
    ios)     echo "voicevox_onnxruntime-ios-xcframework-${VOICEVOX_ONNXRUNTIME_VERSION}.zip" ;;
    android) echo "voicevox_onnxruntime-android-arm64-${VOICEVOX_ONNXRUNTIME_VERSION}.tgz voicevox_onnxruntime-android-x64-${VOICEVOX_ONNXRUNTIME_VERSION}.tgz" ;;
    osx)     echo "voicevox_onnxruntime-osx-arm64-${VOICEVOX_ONNXRUNTIME_VERSION}.tgz voicevox_onnxruntime-osx-x86_64-${VOICEVOX_ONNXRUNTIME_VERSION}.tgz" ;;
    linux)   echo "voicevox_onnxruntime-linux-x64-${VOICEVOX_ONNXRUNTIME_VERSION}.tgz voicevox_onnxruntime-linux-arm64-${VOICEVOX_ONNXRUNTIME_VERSION}.tgz" ;;
    windows) echo "voicevox_onnxruntime-win-x64-${VOICEVOX_ONNXRUNTIME_VERSION}.tgz voicevox_onnxruntime-win-x86-${VOICEVOX_ONNXRUNTIME_VERSION}.tgz" ;;
  esac
}

download() { # url dest
  local url="$1" dest="$2"
  if [[ -f "$dest" ]]; then
    echo "cached: $(basename "$dest")"
  else
    echo "fetch:  $url"
    curl -fL --retry 3 -o "$dest.tmp" "$url"
    mv "$dest.tmp" "$dest"
  fi
}

verify_or_record() { # file
  local f="$1" name sum line
  name="$(basename "$f")"
  sum="$(shasum -a 256 "$f" | awk '{print $1}')"
  if [[ "${UPDATE_CHECKSUMS:-0}" == "1" ]]; then
    touch "$CHECKSUMS"
    grep -v "  ${name}\$" "$CHECKSUMS" > "$CHECKSUMS.tmp" || true
    echo "${sum}  ${name}" >> "$CHECKSUMS.tmp"
    sort "$CHECKSUMS.tmp" > "$CHECKSUMS" && rm "$CHECKSUMS.tmp"
    return 0
  fi
  if [[ -f "$CHECKSUMS" ]] && line="$(grep "  ${name}\$" "$CHECKSUMS")"; then
    if [[ "${line%% *}" != "$sum" ]]; then
      echo "CHECKSUM MISMATCH: $name" >&2
      echo "  expected: ${line%% *}" >&2
      echo "  actual:   $sum" >&2
      exit 1
    fi
    echo "sha256 ok: $name"
  else
    echo "WARN: no recorded checksum for $name (run UPDATE_CHECKSUMS=1 to record)" >&2
  fi
}

extract() { # archive dest_dir
  local a="$1" d="$2"
  mkdir -p "$d"
  case "$a" in
    *.zip) unzip -oq "$a" -d "$d" ;;
    *.tgz|*.tar.gz) tar xzf "$a" -C "$d" ;;
    *) echo "unknown archive type: $a" >&2; return 1 ;;
  esac
}

PLATFORMS=("$@")
[[ ${#PLATFORMS[@]} -eq 0 ]] && PLATFORMS=(ios android osx linux windows)

mkdir -p "$DIST_DIR" "$CACHE_DIR"

for p in "${PLATFORMS[@]}"; do
  echo "== platform: $p =="
  for asset in $(core_assets "$p"); do
    download "$CORE_BASE/$asset" "$CACHE_DIR/$asset"
    verify_or_record "$CACHE_DIR/$asset"
    extract "$CACHE_DIR/$asset" "$DIST_DIR/$p"
  done
  for asset in $(ort_assets "$p"); do
    download "$ORT_BASE/$asset" "$CACHE_DIR/$asset"
    verify_or_record "$CACHE_DIR/$asset"
    extract "$CACHE_DIR/$asset" "$DIST_DIR/$p"
  done
done

# Open JTalk 辞書(全プラットフォーム共通)
dict_archive="$CACHE_DIR/open_jtalk_dic_utf_8-${OPEN_JTALK_DICT_VERSION}.tar.gz"
download "$DICT_URL" "$dict_archive"
verify_or_record "$dict_archive"
extract "$dict_archive" "$DIST_DIR/common"

# C ヘッダを include/ へ同期。
# 公式ヘッダはプラットフォームごとに VOICEVOX_LOAD/LINK_ONNXRUNTIME を
# ハードコードしているため、全プラットフォームで使える条件分岐に正規化する。
header="$(find "$DIST_DIR" -name voicevox_core.h -print -quit)"
if [[ -n "$header" ]]; then
  python3 - "$header" "$ROOT_DIR/include/voicevox_core.h" <<'PYEOF'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src).read()
conditional = """\
// vv-mobile: 単一ヘッダを全プラットフォームで使うため条件分岐に正規化。
// 公式リリースのライブラリは iOS のみリンク時動的リンク(LINK)、
// その他のプラットフォームは実行時ロード(LOAD)。
#if !defined(VOICEVOX_LINK_ONNXRUNTIME) && !defined(VOICEVOX_LOAD_ONNXRUNTIME)
#if defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#define VOICEVOX_LINK_ONNXRUNTIME
#else
#define VOICEVOX_LOAD_ONNXRUNTIME
#endif
#else
#define VOICEVOX_LOAD_ONNXRUNTIME
#endif
#endif
"""
patched, n = re.subn(
    r"^//#define VOICEVOX_(?:LINK|LOAD)_ONNXRUNTIME\n#define VOICEVOX_(?:LINK|LOAD)_ONNXRUNTIME\n",
    conditional,
    text,
    flags=re.M,
)
assert n == 1, f"macro block not found (matched {n})"
open(dst, "w").write(patched)
print("header synced+normalized: include/voicevox_core.h")
PYEOF
fi

echo "done. artifacts in $DIST_DIR"
