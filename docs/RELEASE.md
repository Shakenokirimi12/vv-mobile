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
flutter pub publish --dry-run   # 事前検証(バイナリ同梱サイズに注意)
flutter pub publish
```

注意: pub.dev は100MB制限がある。

**dry-run 実測 (0.1.0)**: pub は git 管理下のリポジトリでは gitignore されたファイルを含めないため、アーカイブは **231KB(圧縮)** に収まる。サイズは問題にならない一方、**バイナリ(ios/macos Frameworks・android jniLibs・assets/open_jtalk_dic)が一切含まれない**ため、pub.dev から取得したパッケージは `prepare-binaries.sh` を実行できず動作しない(pubspec の `assets: assets/open_jtalk_dic/` も実体がなく、利用側のビルドが失敗する)。pub には postinstall フックもない。

**0.1.0 の方針**: pub.dev への公開は**保留**し、**git 依存のみで配布**する(packages/flutter/README.md に記載済み)。将来 pub.dev に公開する場合は、`dart run voicevox_flutter:prepare` のようなバイナリ取得ツール(bin/prepare.dart)を実装し、利用者のアプリ側にバイナリを配置する方式を設計してから行う。

このほか dry-run は `dart analyze` の警告(ffigen 生成の `lib/src/bindings.g.dart` の unused_element 等、計71件)を報告する。公開時は ffigen の preamble に `// ignore_for_file:` を追加して再生成するとよい。

### React Native (npm)

```bash
cd packages/react-native
./scripts/prepare-sources.sh   # vendored ソース・バイナリを最新化
npm run prepare                # builder-bob で lib/ を生成
npm pack --dry-run             # files に vendored 一式が含まれることを確認
npm publish
```

**dry-run 実測 (0.1.0)**: tarball **115.6MB(圧縮)/ 353.9MB(展開後)**、133ファイル。内訳の大どころ: iOS Resources/open_jtalk_dic 102MB + android/vendored/assets/open_jtalk_dic 102MB(同一辞書が iOS/Android で重複)、ios/Frameworks 79MB、android/vendored/jniLibs 31MB、local-maven 23MB。

**公開前の要確認・削減候補**:
- npm レジストリのサイズ上限(一般に tarball 数百MB は要注意)に 115.6MB が収まるか、publish 前に要確認。超える場合は postinstall ダウンロード方式への切り替えが必要
- `ios/Frameworks/*.xcframework` に **macOS スライス(voicevox_onnxruntime だけで約29MB)** が含まれている。RN は iOS のみ対象のため、prepare-sources.sh で macOS スライスを除外すれば削減できる
- Open JTalk 辞書の iOS/Android 重複(102MB×2)は展開後サイズを押し上げるが、両プラットフォームのビルドがそれぞれの場所を参照するため単純には統合できない

## 新リリース検知(自動化TODO)

voicevox_core の新リリースを検知して VERSION 更新のPRを自動作成するワークフローは未実装。GitHub Actions の schedule + `gh api repos/VOICEVOX/voicevox_core/releases/latest` で実装予定。
