# voicevox_flutter

[VOICEVOX CORE](https://github.com/VOICEVOX/voicevox_core) の Flutter バインディング。テキスト読み上げ(TTS)を Flutter アプリから利用できます。

- VOICEVOX CORE 0.16.4(公式ビルド済みバイナリ)ベース
- 音声モデル(.vvm)は**同梱せず実行時ダウンロード** + 利用規約への同意(LicenseGate)必須
- キャラクター / スタイル選択、talk ドメイン判定に対応
- 対応プラットフォーム: iOS / macOS / Android

## インストール

現時点(0.1.0)では **git 依存での利用を想定**しています(pub.dev への公開はネイティブバイナリ同梱サイズの都合で保留中。下記「ネイティブバイナリの準備」参照):

```yaml
dependencies:
  voicevox_flutter:
    git:
      url: https://github.com/shakenokirimi12/vv-mobile.git
      path: packages/flutter
```

## ネイティブバイナリの準備

voicevox_core / VOICEVOX ONNX Runtime / Open JTalk 辞書はリポジトリにコミットされていません。利用前に一度、リポジトリルートで以下を実行してください:

```bash
./packages/core-native/scripts/fetch-core.sh ios osx android
./packages/swift/scripts/prepare-binaries.sh    # iOS/macOS 用 xcframework
./packages/flutter/scripts/prepare-binaries.sh  # Frameworks / jniLibs / 辞書の配置
```

## クイックスタート

```dart
import 'package:voicevox_flutter/voicevox_flutter.dart';

final voicevox = await Voicevox.create();

// 1. モデル一覧(ダウンロード状態・キャラクター・スタイル付き)
final models = voicevox.listModels();

// 2. 利用規約を提示して同意を得てから acceptLicense を呼ぶ(アプリ側の責務)
await voicevox.acceptLicense('0');

// 3. モデルをダウンロード(要同意)
await voicevox.downloadModel('0');

// 4. 合成。styleId は characters[].styles[] から選択(省略時は先頭 talk スタイル)
final wav = await voicevox.synthesis(
  'こんにちは、ずんだもんなのだ',
  modelId: '0',
  styleId: 3,
);
```

`downloadModels(ids)` / `downloadAllModels()` で並列一括ダウンロードもできます(モデルごとの成否を返します)。

## 音声モデルのライセンス

- モデルのダウンロード・ロードには `acceptLicense(modelId)` による**明示的な同意が必須**です。同意前は `LicenseNotAccepted` エラーになります
- 規約の提示 UI はアプリ側で実装してください(`termsURL` と `characters[].termsURL` を提示)
- 生成音声の公開・利用時は `characters[].creditText` の**クレジット表記(例: 「VOICEVOX:ずんだもん」)が必要**です
- キャラクターにより商用利用条件が異なります。詳細は [docs/MODEL_LICENSING.md](../../docs/MODEL_LICENSING.md) を参照

## ライセンス

このパッケージのコードは MIT License です([LICENSE](LICENSE))。VOICEVOX CORE・音声モデルにはそれぞれの規約が適用されます。
