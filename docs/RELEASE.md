# リリース手順

公開は**すべて手動トリガー**(CIはビルド・テストの検証まで)。外部公開は取り消せないため、必ず各パッケージのサンプルアプリでE2E確認をしてから行う。

## voicevox_core のバージョン更新

1. `packages/core-native/VERSION` を新バージョンに更新
2. `UPDATE_CHECKSUMS=1 ./packages/core-native/scripts/fetch-core.sh` で全プラットフォーム再取得+checksums更新
3. `python3 packages/core-native/scripts/gen_licenses.py` で licenses.json 再生成
4. 各パッケージの prepare スクリプトを再実行:
   - `./packages/swift/scripts/prepare-binaries.sh`
   - `./packages/android/scripts/prepare-binaries.sh`
   - `./packages/flutter/scripts/prepare-binaries.sh`
   - `./packages/react-native/scripts/prepare-sources.sh`
5. C APIに変更がある場合: `cd packages/flutter && dart run ffigen --config ffigen.yaml`
6. 全パッケージのテスト(docs/TESTING.md 参照)
7. 各パッケージのバージョンを上げてコミット

## 各パッケージの公開

### Swift (SwiftPM)

xcframework はリポジトリにコミットしないため、リリース時はGitHub Releasesにzipを上げ、`Package.swift` を `url` + `checksum` 形式に書き換えたリリースブランチ/タグを切る:

1. `Binaries/*.xcframework` をそれぞれzip化し、`swift package compute-checksum` でチェックサム取得
2. GitHub Release (`swift-vX.Y.Z`) にzipを添付
3. `Package.swift` の `binaryTarget` を URL+checksum に書き換えてタグ push

### Android (Maven)

```bash
cd packages/android
gradle publishReleasePublicationToMavenLocal   # ローカル確認
# Maven Central: gradle publish(要 signing/sonatype 設定)or JitPack はタグのみ
```

### Flutter (pub.dev)

```bash
cd packages/flutter
flutter pub publish --dry-run   # 事前検証(バイナリ同梱サイズに注意)
flutter pub publish
```

注意: pub.dev は100MB制限がある。xcframework/jniLibs 同梱で超える場合は、Flutter も prepare スクリプト方式(初回ビルド時ダウンロード)への切り替えを検討する。

### React Native (npm)

```bash
cd packages/react-native
./scripts/prepare-sources.sh   # vendored ソース・バイナリを最新化
npm publish --dry-run          # files に vendored 一式が含まれることを確認
npm publish
```

## 新リリース検知(自動化TODO)

voicevox_core の新リリースを検知して VERSION 更新のPRを自動作成するワークフローは未実装。GitHub Actions の schedule + `gh api repos/VOICEVOX/voicevox_core/releases/latest` で実装予定。
