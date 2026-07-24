# 音声モデルのライセンスと配布方針

## なぜモデルを同梱しないのか

VOICEVOX の音声モデル(.vvm)は [VOICEVOX/voicevox_vvm](https://github.com/VOICEVOX/voicevox_vvm) で配布されており、**コード(MIT)とは別の利用規約**が適用される:

- 全モデル共通の「VOICEVOX 音声モデル利用規約」(リバースエンジニアリング禁止、クレジット表記必須など)
- キャラクターごとの個別規約(商用可否・企業利用時の事前確認要否などが異なる)

パッケージにモデルを同梱すると、パッケージ利用者(アプリ開発者)やアプリの利用者が規約に同意する機会がないまま再配布が発生する。そのため本プロジェクトの各パッケージは:

1. **エンジン(voicevox_core + ONNX Runtime + Open JTalk 辞書)のみ同梱**する
2. モデルは**アプリ実行時に voicevox_vvm の GitHub Releases からダウンロード**する
3. ダウンロード・ロードには **LicenseGate による明示的な同意**を必須にする

## LicenseGate の動作

- `acceptLicense(modelId)` を呼ぶまで `downloadModel` / `synthesis` は `LicenseNotAccepted` エラーで拒否される
- 同意状態は (modelId, 規約バージョン) の組で端末に永続化される。規約バージョンが上がると再同意が必要
- パッケージはUIを提供しない。**規約の提示と同意取得はアプリ側の責務**(各パッケージのサンプルアプリに同意ダイアログの実装例あり)

## アプリ開発者がやるべきこと

1. モデルのダウンロード前に、`termsURL`(共通規約)と `characters[].termsURL`(キャラクター個別規約)を利用者に提示する
2. 同意を得てから `acceptLicense(modelId)` を呼ぶ
3. 生成音声を公開・利用する際は `characters[].creditText`(例: **VOICEVOX:ずんだもん**)のクレジット表記を行う
4. キャラクターによっては商用利用に事前確認が必要(例: 青山龍星は企業利用時に事前確認必須、No.7 は非商用が基本)。個別規約を必ず確認すること

## licenses.json の更新

`packages/core-native/scripts/gen_licenses.py` を実行すると、`VERSION` にピン留めされた voicevox_vvm リリースからモデル一覧・キャラクター対応・規約URLを再生成する。voicevox_vvm のバージョンを上げる際は必ず再生成し、各パッケージの同梱コピーを更新する(各 prepare スクリプトが実施)。
