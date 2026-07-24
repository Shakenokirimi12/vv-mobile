# 開発ガイド

## 初回セットアップ

```bash
# 1. 公式ビルド済みバイナリの取得(全プラットフォーム)
./packages/core-native/scripts/fetch-core.sh

# 2. モデルメタデータの生成
python3 packages/core-native/scripts/gen_licenses.py

# 3. 各パッケージへの配置
./packages/swift/scripts/prepare-binaries.sh
./packages/android/scripts/prepare-binaries.sh
./packages/flutter/scripts/prepare-binaries.sh
./packages/react-native/scripts/prepare-sources.sh
```

必要なツール: Xcode / Android SDK (API 35) + JDK 17 / Flutter stable / Node 22+

## 各パッケージのビルド・テスト

| パッケージ | ビルド | テスト |
| --- | --- | --- |
| swift | `swift build`(packages/swift) | `swift test`、E2Eは `VV_E2E=1 swift test` |
| android | `gradle assembleRelease`(packages/android) | `gradle connectedDebugAndroidTest`(要エミュレータ) |
| flutter | `flutter analyze`(packages/flutter) | `flutter test` / example 手動確認 |
| react-native | `npx tsc --noEmit` + `npx nitrogen` | example 手動確認(docs/TESTING.md 参照) |

## 変更時の注意

- **API 契約の変更**は4パッケージすべてに同時反映する(Facade のメソッド名・エラー型・LicenseGate の挙動は共通契約。docs/TESTING.md の共通テストケース参照)
- **RN の spec 変更**時は `npx nitrogen` を再実行し、`nitrogen/generated` をコミットする(CIがドリフトを検知する)
- **バイナリ取得物・生成物はコミットしない**(.gitignore 済み)。コミットするのは VERSION / checksums.txt / licenses.json / 正規化済みヘッダのみ
- voicevox_core のバージョン更新手順は docs/RELEASE.md を参照
