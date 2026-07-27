# リリース手順

公開は**すべて手動トリガー**(CIはビルド・テストの検証まで)。外部公開は取り消せないため、必ず各パッケージのサンプルアプリでE2E確認をしてから行う。

## voicevox_core のバージョン更新

1. `packages/core-native/VERSION` を新バージョンに更新
2. `UPDATE_CHECKSUMS=1 ./packages/core-native/scripts/fetch-core.sh` で全プラットフォーム再取得+checksums更新
3. `python3 packages/core-native/scripts/gen_licenses.py` で licenses.json 再生成
4. 各パッケージの prepare スクリプトを再実行:
   - `./packages/swift/scripts/prepare-binaries.sh`
   - `./packages/android/scripts/prepare-binaries.sh`
   - `./packages/flutter/scripts/prepare-binaries.sh`
   - `./packages/react-native/scripts/prepare-sources.sh`
5. C APIに変更がある場合: `cd packages/flutter && dart run ffigen --config ffigen.yaml`
6. 全パッケージのテスト(docs/TESTING.md 参照)
7. 各パッケージのバージョンを上げてコミット

## 各パッケージの公開

`.github/workflows/release.yml`(workflow_dispatch、`package` 入力で選択)がビルド + dry-run + 成果物アップロードまでを行う。**publish 自体はワークフローに含めない**(手動承認方針)。

### Swift (SwiftPM)

xcframework はリポジトリにコミットしないため、リリース時はGitHub Releasesにzipを上げ、`Package.swift` を `url` + `checksum` 形式に書き換えたリリースブランチ/タグを切る:

1. `./tools/release/prepare-swift-release.sh [version]` を実行すると `packages/swift/.release/` に zip を生成し、checksum と `binaryTarget(url:checksum:)` スタンザを出力する(タグ規約: `swift-vX.Y.Z`)
2. GitHub Release (`swift-vX.Y.Z`) にzipを添付
3. `Package.swift` の `binaryTarget` を出力されたスタンザ(URL+checksum)に書き換えてタグ push

実測 (0.16.4): `voicevox_core.xcframework.zip` 約5.6MB、`voicevox_onnxruntime.xcframework.zip` 約24MB。

### Android (Maven)

```bash
cd packages/android
gradle :lib:publishReleasePublicationToMavenLocal   # ローカル確認
# Maven Central: gradle publish(要 signing/sonatype 設定)or JitPack はタグのみ
```

実測 (0.1.0): AAR 約34.8MB(Open JTalk 辞書を assets に同梱するため)。`~/.m2/repository/jp/voicevox/voicevox-core-android/0.1.0/` に AAR / sources.jar / pom / module が生成されることを確認済み。

**公開ブロッカー**: 本ライブラリは `jp.hiroshiba.voicevoxcore:voicevoxcore-android:0.16.4` に `api` 依存するが、この公式 AAR は **Maven Central 未公開**(公式配布 `java_packages.zip` から `packages/android/local-maven/` に展開して解決している)。そのため Maven Central に公開しても利用者は依存解決できない。選択肢:
1. 利用者にも local-maven 方式を案内する(packages/android/README.md に記載済み)— 当面はこの方式
2. 上流(VOICEVOX)が Maven リポジトリへ公開するのを待ってから Central 公開する

### Flutter (pub.dev)

```bash
cd packages/flutter
flutter pub publish --dry-run
flutter pub publish
```

**0.1.0 の失敗と 0.1.1 での修正**: pub は git 管理下のリポジトリで gitignore 対象を
除外するため、0.1.0 の配布物には**ネイティブバイナリも Open JTalk 辞書も含まれず**、
利用者側では初期化時に `Failed to load dynamic library` で失敗していた
(クリーンなアプリで再現確認済み)。0.1.0 は retract 済み。

0.1.1 では以下の方式に変更し、**バイナリを一切含まないまま動作する**ようにした:

| 対象 | 取得タイミング | 実装 |
| --- | --- | --- |
| voicevox_core / ONNX Runtime (iOS/macOS) | ビルド時 | podspec の `prepare_command` → `scripts/fetch-native.sh` |
| voicevox_core / ONNX Runtime / libc++_shared (Android) | ビルド時 | Gradle タスク `downloadVoicevoxNatives`(JVM のみ) |
| Open JTalk 辞書(約100MB) | アプリ初回起動時 | `DictionaryManager`(`archive` でストリーム展開) |

ネイティブバイナリは配置済みならスキップする冪等な実装で、モノレポ開発時は
`prepare-binaries.sh` が置いたものがそのまま使われる。**辞書は例外で、モノレポ
開発時も初回起動時にダウンロードされる**(pubspec の assets から外したため、
`prepare-binaries.sh` は辞書を配置しない)。

実装上の注意:
- **iOS ではプロセス起動が禁止**されているため、辞書展開に `tar` コマンドは使えない
  (`ProcessException: Starting new processes is not supported on iOS`)。
  `package:archive` の `extractFileToDisk` によるストリーム展開にしてある。
  一括展開すると gz 全体と `sys.dic`(約103MB)が同時にメモリへ載って OOM するため、
  ストリーム化した上で `Isolate.run` で UI スレッドから逃がしている
- ダウンロードしたものは辞書・ネイティブバイナリとも sha256 を検証する
  (`packages/core-native/checksums.txt` と同じ値。特に辞書は sourceforge が
  任意のミラーへリダイレクトするため必須)
- 公式 iOS フレームワークの `CFBundleIdentifier` にはアンダースコアが含まれ、
  Xcode 16+ の埋め込み検証で拒否されるため fetch-native.sh 側で正規化している
- Android の `libvoicevox_core.so` は `libc++_shared.so` に動的リンクするため、
  NDK から取り出して同梱する(NDK 必須)。取得は bash ではなく Gradle/JVM で
  行う — bash 前提だと Windows ホストで Android ビルドができなくなるため

アーカイブサイズは **232KB(圧縮)**。

### React Native (npm)

```bash
cd packages/react-native
./scripts/prepare-sources.sh   # vendored ソース・バイナリを最新化
npm run prepare                # builder-bob で lib/ を生成
npm pack --dry-run             # files に vendored 一式が含まれることを確認
npm publish
```

**公開実測 (0.1.0)**: tarball **102MB(圧縮)/ 318MB(展開後)**、131ファイル。npm は受理した。
内訳の大どころ: iOS Resources/open_jtalk_dic 102MB + android/vendored/assets/open_jtalk_dic 102MB
(同一辞書が iOS/Android で重複)、ios/Frameworks 45MB、android/vendored/jniLibs 31MB、local-maven 23MB。

公開時に `files` へ除外パターン(`!android/build` など)を追加した。これが無いと
gradle/CMake のビルド中間物(`libreactnative.so` 156MB×2 など)が混入し **463MB** に膨らむ。
`.npmignore` は `files` 指定があると無視されるため、除外は `files` 側に書くこと。

**将来の削減候補**: Flutter 0.1.1 と同様にバイナリ・辞書を postinstall / ビルド時
ダウンロードへ移せば tarball は数百KBまで縮む。

## 新リリース検知(自動化TODO)

voicevox_core の新リリースを検知して VERSION 更新のPRを自動作成するワークフローは未実装。GitHub Actions の schedule + `gh api repos/VOICEVOX/voicevox_core/releases/latest` で実装予定。
