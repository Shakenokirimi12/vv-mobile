# vv-mobile

[VOICEVOX CORE](https://github.com/VOICEVOX/voicevox_core) を Swift / Kotlin(Java) / Flutter / React Native から利用するためのマルチプラットフォームパッケージ群。

## パッケージ

| ディレクトリ | 配布先 | 対象 |
| --- | --- | --- |
| `packages/swift` | SwiftPM (`VoicevoxCore`) | iOS / macOS |
| `packages/android` | Maven (`jp.voicevox:voicevox-core-android`) | Android (Kotlin / Java) |
| `packages/flutter` | pub.dev (`voicevox_flutter`) | Flutter |
| `packages/react-native` | npm (`react-native-voicevox`) | React Native (Nitro Modules) |
| `packages/core-native` | (内部) | 公式ビルド済みバイナリの取得・バージョン管理 |

## 設計の要点

- エンジン(voicevox_core + VOICEVOX ONNX Runtime + Open JTalk 辞書)はパッケージに同梱、音声モデル(.vvm)は**同梱せず実行時ダウンロード**
- モデルの取得・ロードは各キャラクターの利用規約への**同意(LicenseGate)が必須**
- 全パッケージ共通の Facade API: `listModels()` / `downloadModel(s)` / `downloadAllModels()` / `synthesis(text, modelId)`
- ダウンロードは各言語の並行処理プリミティブ(Swift Concurrency / Kotlin Coroutines / Dart Future)で並列実行

詳細は `docs/ARCHITECTURE.md` を参照。

## サンプルアプリ

各パッケージに、規約同意ダイアログ・モデルダウンロード・合成再生を実装したサンプルアプリがあります:

- `packages/swift/Example/` — SwiftUI(iOS / macOS)
- `packages/android/example/` — Jetpack Compose
- `packages/flutter/example/` — Flutter
- `packages/react-native/example/` — React Native(New Architecture)

## 開発

```bash
# 公式バイナリの取得(初回)
./packages/core-native/scripts/fetch-core.sh

# モデルメタデータ(licenses.json)の再生成
python3 packages/core-native/scripts/gen_licenses.py
```

## ライセンス

コードは MIT License([LICENSE](LICENSE))。VOICEVOX CORE および音声モデル(.vvm)にはそれぞれの利用規約が適用される(`docs/MODEL_LICENSING.md` 参照)。
