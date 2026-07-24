#!/usr/bin/env bash
# Swift リリース準備: Binaries/*.xcframework を zip 化し、checksum を計算して
# Package.swift に貼り付ける binaryTarget スタンザを出力する。
#
# 使い方:
#   ./tools/release/prepare-swift-release.sh [version]
# version 省略時は 0.1.0。zip は packages/swift/.release/ に生成される(gitignore 済み)。
# GitHub Release (swift-v<version>) にこの zip を添付し、出力されたスタンザで
# Package.swift の binaryTarget を書き換えてタグを push する(docs/RELEASE.md 参照)。
set -euo pipefail

VERSION="${1:-0.1.0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SWIFT_DIR="$REPO_ROOT/packages/swift"
BINARIES_DIR="$SWIFT_DIR/Binaries"
OUT_DIR="$SWIFT_DIR/.release"
RELEASE_URL_BASE="https://github.com/vv-mobile/vv-mobile/releases/download/swift-v${VERSION}"

if [[ ! -d "$BINARIES_DIR/voicevox_core.xcframework" ]]; then
  echo "error: $BINARIES_DIR/voicevox_core.xcframework がありません。" >&2
  echo "       先に ./packages/core-native/scripts/fetch-core.sh ios osx && ./packages/swift/scripts/prepare-binaries.sh を実行してください。" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

stanzas=""
for name in voicevox_core voicevox_onnxruntime; do
  zip_path="$OUT_DIR/${name}.xcframework.zip"
  rm -f "$zip_path"
  echo "==> zipping ${name}.xcframework"
  (cd "$BINARIES_DIR" && ditto -c -k --keepParent "${name}.xcframework" "$zip_path")
  checksum="$(cd "$SWIFT_DIR" && swift package compute-checksum "$zip_path")"
  size="$(du -h "$zip_path" | cut -f1)"
  echo "    ${zip_path} (${size})"
  echo "    checksum: ${checksum}"
  stanzas+="        .binaryTarget(
            name: \"${name}_binary\",
            url: \"${RELEASE_URL_BASE}/${name}.xcframework.zip\",
            checksum: \"${checksum}\"
        ),
"
done

cat <<EOF

==> Package.swift の binaryTarget をリリース用に書き換える場合は以下を使用:

${stanzas}
==> 次の手順:
  1. GitHub Release (swift-v${VERSION}) を作成し、$OUT_DIR/*.zip を添付
  2. Package.swift の .binaryTarget(path:) を上記の url + checksum 形式に書き換え
  3. タグ swift-v${VERSION} を push
EOF
