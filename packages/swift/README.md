# VoicevoxCore (Swift)

[VOICEVOX CORE](https://github.com/VOICEVOX/voicevox_core) の Swift バインディング(SwiftPM)。iOS / macOS アプリからテキスト読み上げ(TTS)を利用できます。

- VOICEVOX CORE 0.16.4(公式ビルド済みバイナリ)ベース
- `actor Voicevox` による Swift Concurrency 対応の Facade API
- 音声モデル(.vvm)は**同梱せず実行時ダウンロード** + 利用規約への同意(LicenseGate)必須
- 対応プラットフォーム: iOS 15+ / macOS 13+

## インストール

```swift
dependencies: [
    .package(url: "https://github.com/Shakenokirimi12/vv-mobile.git", exact: "0.1.1")
]
```

Xcode から追加する場合も、リポジトリURLに `https://github.com/Shakenokirimi12/vv-mobile.git`、バージョン指定に `Exact: 0.1.1` を入れてください。

**バージョンは `swift-v0.1.1` ではなく `0.1.1` を指定してください。** SwiftPM はタグをセマンティックバージョンとして解釈するため、`swift-v` のような接頭辞つきタグは解決できません。リリースごとに、パッケージを区別するための `swift-vX.Y.Z` と、SwiftPM 用の `X.Y.Z` の両方を打っています(同じコミットを指しています)。

**必ずリリースタグを指定してください。** SwiftPM はリポジトリの**ルート**にある `Package.swift` しか読まないため、ルートのマニフェストは常にリリース済み xcframework を URL + checksum で取得する形になっています。また Open JTalk 辞書(約107MB)は通常 gitignore されており、**リリースタグにのみコミットされています**。`main` ブランチを直接指定すると辞書が入らず、初期化時に失敗します。

`swift-v0.1.0` はルートに `Package.swift` が無く、SwiftPM 用のセマンティックバージョンタグも無かったため解決できません。**`0.1.1` 以降を使ってください**。

### バイナリ(xcframework)について

`Binaries/*.xcframework` はリポジトリにコミットされていません。

- **リリースタグ(`swift-vX.Y.Z`)経由**: `Package.swift` の `binaryTarget` が URL + checksum 形式になっており、SwiftPM が自動取得します(docs/RELEASE.md 参照)
- **main ブランチ / ローカル開発**: リポジトリルートで以下を実行して配置してください

```bash
./packages/core-native/scripts/fetch-core.sh ios osx
./packages/swift/scripts/prepare-binaries.sh
```

## クイックスタート

```swift
import VoicevoxCore

let voicevox = try Voicevox()

// 1. モデル一覧(ダウンロード状態・キャラクター・スタイル付き)
let models = await voicevox.listModels()

// 2. 利用規約を提示して同意を得てから acceptLicense(アプリ側の責務)
//    共通規約は voicevox.termsURL、個別規約は characters[].termsURL
voicevox.acceptLicense(modelId: "0")

// 3. ダウンロード(要同意)。複数は downloadModels / downloadAllModels
try await voicevox.downloadModel(id: "0")

// 4. 合成(WAV の Data が返る)。styleId 省略時は先頭 talk スタイル
let wav = try await voicevox.synthesis(
    text: "こんにちは、ずんだもんなのだ",
    modelId: "0",
    styleId: 3
)
```

## 音声モデルのライセンス

- モデルのダウンロード・合成には `acceptLicense` による**明示的な同意が必須**です
- 規約の提示 UI はアプリ側で実装してください(`Example/` に同意ダイアログの実装例があります)
- 生成音声の公開・利用時は `creditText`(例: 「VOICEVOX:ずんだもん」)の**クレジット表記が必要**です
- 詳細は [docs/MODEL_LICENSING.md](../../docs/MODEL_LICENSING.md) を参照

## ライセンス

このパッケージのコードは MIT License です([LICENSE](LICENSE))。VOICEVOX CORE・音声モデルにはそれぞれの規約が適用されます。
