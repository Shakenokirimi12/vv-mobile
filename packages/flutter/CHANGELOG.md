# Changelog

## 0.1.0

初回リリース。

- VOICEVOX CORE 0.16.4 の Flutter バインディング(ffigen による FFI + Dart Facade)
- 音声モデル(.vvm)の実行時ダウンロード(voicevox_vvm GitHub Releases から取得)
- LicenseGate による利用規約同意ゲート(`acceptLicense` するまでダウンロード・合成を拒否)
- キャラクター / スタイル選択(`synthesis` の `styleId` 指定、省略時は先頭 talk スタイル)
- talk ドメイン対応の判定(歌唱専用モデル `frame_decode` を `synthesis` で誤用した際の明示エラー)
- `listModels` / `downloadModel(s)` / `downloadAllModels`(並列ダウンロード)/ `synthesis` の共通 Facade API
- iOS / macOS / Android 対応(ネイティブバイナリは `scripts/prepare-binaries.sh` で配置)
