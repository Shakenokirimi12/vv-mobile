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

## Flutter (packages/flutter) — 済(iOS)

`flutter test integration_test/voicevox_test.dart -d <iOSシミュレータUDID>` で5/5通過(21秒)。

- 済 C1 (`listModels returns all models with characters`)
- 済 C6 (`synthesis without download throws ModelNotDownloadedException`)
- 済 C2 (`download without license throws LicenseNotAcceptedException`)
- 済 C3, C7 (`end-to-end: accept, download, synthesize, RIFF header`)
- 済 C9, C10 (`parallel download with partial failure`)
- 未 Android実機/エミュレータでの同テスト実行(iOSのみ確認済み)
- 未 C4, C5, C8, C11, C12 の明示的テスト

### 発覚した問題と修正(iOSビルド)

1. **SwiftPMプラグインのディレクトリ名不一致**: Flutterはプラグインルートのディレクトリ名(`packages/flutter`)からiOS/macOSのSwiftPMサブパッケージ名を`<root>/ios/<root名>`と推測する。当初`ios/voicevox_flutter/`だったため`unable to override package`エラーになった。→ 結局SwiftPM統合は諦め、CocoaPods(`vendored_frameworks`)方式に切り替え(`ios/voicevox_flutter.podspec`, `macos/voicevox_flutter.podspec`)。xcframeworkの埋め込みはCocoaPodsの方が確実
2. **CocoaPodsが動作していなかった**: rbenvで有効なRuby(3.4.9)にcocoapods gemが入っておらず、かつ`.rbenv/shims/.rbenv-shim`の残留ロックでrehashも失敗していた。`gem install cocoapods` + ロックファイル削除で解消
3. **iOSデプロイターゲット不足**: example側が13.0のままだったため、プラグイン(15.0)より低くpod installが失敗。`ios/Podfile`と`project.pbxproj`を15.0に統一
4. **公式onnxruntimeフレームワークのBundleIdentifier不正**: 配布物の`CFBundleIdentifier`が`jp.hiroshiba.voicevox.voicevox_onnxruntime`とアンダースコアを含んでおり、Xcode 16+の埋め込み検証で拒否される。`packages/swift/scripts/prepare-binaries.sh`でxcframework化前にコピーしてハイフンに書き換えるよう修正(自前生成のmacOS用Info.plistも同様にハイフン化)

- 未 example アプリの手動動作確認(Android)

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
