# テストケースメモ

実装済み・未実施のテストケース一覧。「済」は実行して通過済み、「未」はテストコード未作成または未実行。

## 共通テストケース(全プラットフォーム同一契約)

| # | ケース | 期待動作 |
| --- | --- | --- |
| C1 | `listModels()` | 27モデル(0〜24, n0, s0)が返り、全モデルに characters / styles / downloadURL がある |
| C2 | 未同意で `downloadModel` | `LicenseNotAccepted` エラー |
| C3 | 同意後に `downloadModel` | 成功し `isDownloaded=true` になる |
| C4 | 規約バージョン変更 | 再同意が必要になる(旧バージョンの同意は無効) |
| C5 | `revoke` 後 | 再び未同意扱い |
| C6 | 未ダウンロードで `synthesis` | `ModelNotDownloaded` エラー(暗黙DLしない) |
| C7 | ダウンロード済みで `synthesis` | RIFFヘッダ付きWAVが返る(>44バイト、24kHz mono) |
| C8 | 2回目の `synthesis` | モデル再ロードなしで成功(キャッシュ) |
| C9 | `downloadModels` 並列 | 同時実行数上限を守り、全件成功 |
| C10 | `downloadModels` 部分失敗 | 未同意モデルのみ失敗、他は成功(全滅しない) |
| C11 | 不明モデルID | `UnknownModel` エラー |
| C12 | ダウンロード済みモデルの再DL | 何もせず成功(冪等) |

## Swift (packages/swift) — 済

`swift test` / `VV_E2E=1 swift test` で実行。

- 済 C1 (`testCatalogDecodes`)
- 済 C2, C4, C5 (`testLicenseGateBlocksAndAccepts`)
- 済 C6 (`testSynthesisFailsWithoutDownload`)
- 済 初期化+バージョン確認 (`testSynthesizerInitAndVersion`, macOS/iOSシミュレータ両方)
- 済 C3, C7 (`testEndToEndSynthesis`, macOS: 2.56秒の実音声を確認)
- 済 C9, C10 (`testParallelDownload`)
- 未 C8, C11, C12 の明示的テスト
- 未 iOSシミュレータでのE2E(ユニットテストは通過済み、E2EはmacOSのみ)

## Kotlin/Android (packages/android) — 済

`gradle connectedDebugAndroidTest`(API 35 arm64 エミュレータ)で5/5通過。

- 済 C1 (`listModels_returnsAllModelsWithCharacters`)
- 済 C6 (`synthesisWithoutDownload_throwsModelNotDownloaded`)
- 済 C2 (`downloadWithoutLicense_throwsLicenseNotAccepted`)
- 済 C3, C7 (`endToEndSynthesis`, エミュレータ上で実合成)
- 済 C9, C10 (`parallelDownload_partialFailure`)
- 未 C4, C5, C8, C11, C12 の明示的テスト

## Flutter (packages/flutter) — 未

テストコード未作成。作成すべきテスト:

- 未 単体: `LicenseCatalog.fromJson`(assets/licenses.json のパース、C1相当)
- 未 単体: `LicenseGate`(SharedPreferences モックで C2, C4, C5)
- 未 統合(integration_test, 実機/エミュレータ): C3, C6, C7, C9, C10
  - `Voicevox.create()` → `listModels` → `acceptLicense('0')` → `downloadModel('0')` → `synthesis()` → RIFF確認
  - ffigen バインディング経由の実ネイティブ呼び出し検証(iOS: init_once 手動lookupの動作確認を含む)
- 未 example アプリの手動動作確認(iOS/Android)

## React Native (packages/react-native) — 未

TypeScript typecheck のみ通過済み。作成すべきテスト:

- 未 example アプリ(RN 0.81 + Nitro)での手動E2E: initialize → listModels → acceptLicense → downloadModel → synthesis → 再生
- 未 iOS: `pod install` → ビルド確認(RNVoicevox.podspec の vendored xcframework + BundleModuleShim の動作)
- 未 Android: gradle ビルド確認(vendored/ ソース複製 + nitrogen autolinking)
- 未 C2, C6, C10 のJS層からの確認(ネイティブ層は Swift/Kotlin テストでカバー済み)

## CI で自動化すべきもの(tools/release 参照)

- Swift: `swift build` + `swift test`(macOS runner)、iOSシミュレータテスト
- Android: `gradle assembleRelease` + `gradle test`、(エミュレータが使えるrunnerで)connectedAndroidTest
- Flutter: `flutter analyze` + `flutter test`
- RN: `npx tsc --noEmit` + `npx nitrogen`(生成物の差分チェック)
- E2E(実ダウンロード含む)は nightly のみ実行
