# react-native-voicevox

[VOICEVOX CORE](https://github.com/VOICEVOX/voicevox_core) の React Native バインディング([Nitro Modules](https://nitro.margelo.com/) 使用)。テキスト読み上げ(TTS)を React Native アプリから利用できます。

- VOICEVOX CORE 0.16.4(公式ビルド済みバイナリ)ベース
- ネイティブ実装は `packages/swift` / `packages/android` の Facade を呼ぶ薄いグルー(JSI 経由で直接呼び出し)
- 音声モデル(.vvm)は**同梱せず実行時ダウンロード** + 利用規約への同意(LicenseGate)必須
- 対応プラットフォーム: iOS / Android(New Architecture 必須)

## インストール

```bash
npm install react-native-voicevox react-native-nitro-modules
cd ios && pod install
```

npm パッケージには iOS の xcframework・vendored Swift/Kotlin ソース・Android の依存物が同梱されています。リポジトリから直接使う場合は `./scripts/prepare-sources.sh` で vendored 一式を生成してください。

## クイックスタート

```ts
import { getVoicevox } from 'react-native-voicevox'

const voicevox = getVoicevox()

// 1. ネイティブ初期化(ONNX Runtime・辞書展開)。最初に1回呼ぶ
await voicevox.initialize(4) // 並列ダウンロード数

// 2. モデル一覧(ダウンロード状態・キャラクター・スタイル付き)
const models = await voicevox.listModels()

// 3. 利用規約を提示して同意を得てから acceptLicense(アプリ側の責務)
//    共通規約は voicevox.getTermsURL()、個別規約は characters[].termsURL
voicevox.acceptLicense('0')

// 4. ダウンロード(要同意)。複数は downloadModels / downloadAllModels
await voicevox.downloadModel('0')

// 5. 合成。ArrayBuffer(WAV)が返る。styleId 省略時は先頭スタイル
const wav: ArrayBuffer = await voicevox.synthesis('こんにちは、ずんだもんなのだ', '0', 3)
```

`downloadModels(ids)` / `downloadAllModels()` は一部失敗でも reject せず、`DownloadResult[]`(モデルごとの成否)を返します。

## 音声モデルのライセンス

- モデルのダウンロード・合成には `acceptLicense(modelId)` による**明示的な同意が必須**です。同意前はエラーになります
- 規約の提示 UI はアプリ側で実装してください(example アプリに同意ダイアログの実装例があります)
- 生成音声の公開・利用時は `characters[].creditText` の**クレジット表記(例: 「VOICEVOX:ずんだもん」)が必要**です
- キャラクターにより商用利用条件が異なります。詳細は [docs/MODEL_LICENSING.md](../../docs/MODEL_LICENSING.md) を参照

## ライセンス

このパッケージのコードは MIT License です([LICENSE](LICENSE))。VOICEVOX CORE・音声モデルにはそれぞれの規約が適用されます。
