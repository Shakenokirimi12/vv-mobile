# Changelog

## 0.1.1

**0.1.0 は pub.dev 経由では動作しません。0.1.1 以降を使ってください。**

pub.dev の配布物にはネイティブバイナリと Open JTalk 辞書が含まれず(pub が
gitignore 対象を除外するため)、初期化時に `Failed to load dynamic library` で
失敗していた。0.1.1 でこれを解消:

- ネイティブバイナリ(voicevox_core / VOICEVOX ONNX Runtime)を**ビルド時に自動ダウンロード**
  - iOS / macOS: podspec の `prepare_command`
  - Android: Gradle タスク `downloadVoicevoxNatives`
  - いずれも配置済みならスキップする冪等な処理(モノレポ開発時は既存のまま)
- Open JTalk 辞書(約100MB)を Flutter アセットから外し、**初回起動時のダウンロード**に変更
  - `Voicevox.create(onDictionaryProgress: ...)` で進捗を取得できる
  - 展開は純 Dart(`archive`)で行う(iOS はプロセス起動が禁止されているため)
- iOS フレームワークの `CFBundleIdentifier` のアンダースコアを自動修正
  (Xcode 16+ の埋め込み検証を通すため)

## 0.1.0

初回リリース。

- VOICEVOX CORE 0.16.4 の Flutter バインディング(ffigen による FFI + Dart Facade)
- 音声モデル(.vvm)の実行時ダウンロード(voicevox_vvm GitHub Releases から取得)
- LicenseGate による利用規約同意ゲート(`acceptLicense` するまでダウンロード・合成を拒否)
- キャラクター / スタイル選択(`synthesis` の `styleId` 指定、省略時は先頭 talk スタイル)
- talk ドメイン対応の判定(歌唱専用モデル `frame_decode` を `synthesis` で誤用した際の明示エラー)
- `listModels` / `downloadModel(s)` / `downloadAllModels`(並列ダウンロード)/ `synthesis` の共通 Facade API
- iOS / macOS / Android 対応(ネイティブバイナリは `scripts/prepare-binaries.sh` で配置)
