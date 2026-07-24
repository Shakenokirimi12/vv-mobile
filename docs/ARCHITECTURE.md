# アーキテクチャ

## 全体方針

- 音声合成コアは [voicevox_core](https://github.com/VOICEVOX/voicevox_core) の**公式ビルド済みバイナリ**を使用する(自前ビルドしない)。`packages/core-native` がバージョンのピン留めと取得・検証を担う
- 各言語パッケージは C API への薄いバインディング + 共通契約の Facade(`listModels` / `downloadModel(s)` / `downloadAllModels` / `synthesis`)を提供する
- React Native は Nitro Modules の HybridObject を Swift/Kotlin で実装し、`packages/swift` / `packages/android` の Facade を呼ぶだけのグルーに留める(バインディングの二重実装をしない)
- 音声モデル(.vvm)は同梱せず実行時に [voicevox_vvm](https://github.com/VOICEVOX/voicevox_vvm) の GitHub Releases から取得する。取得・ロードには LicenseGate による利用規約同意が必須

## 実行時に必要なアセット

| アセット | 配布元 | パッケージ同梱 |
| --- | --- | --- |
| voicevox_core (C API) | voicevox_core releases | ✅ |
| VOICEVOX ONNX Runtime | onnxruntime-builder releases | ✅ |
| Open JTalk 辞書 | sourceforge (open_jtalk_dic_utf_8) | ✅ |
| 音声モデル (.vvm) | voicevox_vvm releases | ❌ 実行時DL + 規約同意 |

## ハードウェアアクセラレーション調査 (2026-07-24, voicevox_onnxruntime 1.17.3)

公式配布の VOICEVOX ONNX Runtime バイナリを確認した結果:

- **iOS (xcframework)**: CoreML Execution Provider のシンボルは含まれていない(`nm -gU` でCoreML関連シンボル0件)。CPU実行のみ
- **Android (.so)**: NNAPI Execution Provider も実質含まれていない(文字列参照が1件のみで、EP登録シンボルなし)
- 本家でも [CoreML EP 対応は Issue #428](https://github.com/VOICEVOX/voicevox_core/issues/428) で検討段階

**結論**: 現時点ではEP選択オプションをAPIに載せても実体がないため実装しない。公式がEP入りビルドを配布し始めた時点で、`Synthesizer` 初期化オプション(accelerationMode)として追加する。自前でEP有効化ビルドを行う案は、保守コスト(onnxruntime-builderのフォーク維持)が高いため見送り。

## パッケージ間の実装共有

- **Swift (`packages/swift`)**: 唯一の iOS/macOS 実装。C API を modulemap 経由で直接呼ぶ。バイナリは `scripts/prepare-binaries.sh` が iOS スライスと macOS dylib を1つの xcframework に統合して配置する(macOS dylib は framework バンドル化してから統合)
- **Android (`packages/android`)**: 公式 `voicevoxcore-android` AAR(JNIブリッジ内蔵)に依存し、Kotlin で idiomatic なラッパー(suspend / LicenseGate / Facade)を被せる。JNI の重複実装はしない
- **Flutter (`packages/flutter`)**: Dart は C++/Swift/Kotlin を直接呼べないため独立実装。`ffigen` で C ヘッダから自動生成したバインディング + Dart Facade。iOS のみ `voicevox_onnxruntime_init_once` を手動 lookup(ヘッダの LINK/LOAD マクロ分岐のため)。iOS/macOS の xcframework 埋め込みは SwiftPM 統合ではなく **CocoaPods(`vendored_frameworks`)** を使う(SwiftPM経由だとFlutterのプラグイン集約パッケージ配下でバイナリターゲットが自動埋め込みされない問題があったため。詳細は docs/TESTING.md)
- **React Native (`packages/react-native`)**: Nitro Modules。`HybridVoicevox.swift/kt` は Swift/Kotlin パッケージの Facade を呼ぶだけの薄いグルー(各数十行)。`scripts/prepare-sources.sh` が packages/swift・packages/android の実装を vendored ディレクトリに複製して npm パッケージに同梱する(単一実装の複製方式。CocoaPods では SwiftPM の `Bundle.module` が無いため `BundleModuleShim.swift` を追加)

C ヘッダは公式配布物がプラットフォームごとに `VOICEVOX_LOAD/LINK_ONNXRUNTIME` をハードコードしているため、`fetch-core.sh` の同期時に条件分岐へ正規化し、全プラットフォームで単一ヘッダを共有する。

## licenses.json

`packages/core-native/scripts/gen_licenses.py` が voicevox_vvm リリースの各 .vvm の zip 構造を HTTP Range リクエストで部分読みし、`manifest.json` / `metas.json` からモデル→キャラクター対応を抽出して `generated/licenses.json` を生成する(モデル本体はダウンロードしない)。各言語パッケージはこのJSONを同梱リソースとして参照する。

- モデルID = リリースアセット名から拡張子を除いたもの(`0`〜`24`, `n0`, `s0`)
- `s0` は全キャラクター同梱の大型モデル(約130MB)、`0`〜`24` はキャラクター別の分割モデル(約55-65MB)
- キャラクターごとの `creditText`("VOICEVOX:〇〇")と `termsURL` を含む
