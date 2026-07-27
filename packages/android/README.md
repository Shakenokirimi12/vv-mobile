# voicevox-core-android (Kotlin)

[VOICEVOX CORE](https://github.com/VOICEVOX/voicevox_core) の Android 用 Kotlin ラッパー。suspend 関数ベースの Facade でテキスト読み上げ(TTS)を利用できます。

- 公式 `voicevoxcore-android` AAR(VOICEVOX CORE 0.16.4、JNI ブリッジ内蔵)への薄い idiomatic ラッパー
- Kotlin Coroutines(suspend / 並列ダウンロード)対応
- 音声モデル(.vvm)は**同梱せず実行時ダウンロード** + 利用規約への同意(LicenseGate)必須
- minSdk 26

## インストール

JitPack から取得できます。`settings.gradle.kts`(または `build.gradle`)にリポジトリを追加してください。

```kotlin
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
```

```kotlin
// app/build.gradle.kts
dependencies {
    implementation("com.github.Shakenokirimi12.vv-mobile:voicevox-core-android:android-v0.1.3")
}
```

`minSdk` は 26 以上が必要です。ネイティブライブラリは `arm64-v8a` / `x86_64` のみを同梱しています。AAR は Open JTalk 辞書を同梱するため約 35MB あります。

### 依存する公式 AAR について

本ライブラリは公式 Java API `jp.hiroshiba.voicevoxcore:voicevoxcore-android:0.16.4` に `api` 依存しますが、この AAR は **Maven Central には公開されていません**(公式配布の `java_packages.zip` に Maven リポジトリ形式で同梱)。

そのため JitPack 公開時に、公式 AAR も同じタグのバージョンで併せて発行し、`com.github.Shakenokirimi12.vv-mobile:voicevoxcore-android:<タグ>` として配信しています。利用側で追加の設定は不要です(`android-v0.1.0` はこの再発行が無く依存解決に失敗するため、**`android-v0.1.1` 以降を使ってください**)。

モノレポ内で開発する場合は `./packages/core-native/scripts/fetch-core.sh android` → `./packages/android/scripts/prepare-binaries.sh` を実行すると `packages/android/local-maven/` に展開され、そこから解決されます。

## クイックスタート

```kotlin
import jp.voicevox.android.Voicevox

// 1. 初期化(辞書展開・ONNX Runtime ロード)。suspend
val voicevox = Voicevox.create(context)

// 2. モデル一覧(ダウンロード状態・キャラクター・スタイル付き)
val models = voicevox.listModels()

// 3. 利用規約を提示して同意を得てから acceptLicense(アプリ側の責務)
voicevox.acceptLicense("0")

// 4. ダウンロード(要同意)。複数は downloadModels / downloadAllModels
voicevox.downloadModel("0")

// 5. 合成(WAV の ByteArray が返る)。styleId 省略時は先頭 talk スタイル
val wav = voicevox.synthesis("こんにちは、ずんだもんなのだ", modelId = "0", styleId = 3)
```

`downloadModels(ids)` / `downloadAllModels()` は並列実行され、モデルごとの `Result` を返します(一部失敗でも例外を投げません)。

### 一覧表示だけなら VoicevoxCatalog

`Voicevox.create` は ONNX Runtime のロードと Open JTalk 辞書(約100MB)の展開を伴い、初回は時間がかかります。キャラクター一覧やダウンロード状態を出したいだけの画面では、ネイティブ初期化なしで読める `VoicevoxCatalog` を使ってください。

```kotlin
val catalog = VoicevoxCatalog.load(context)
catalog.models()                  // ダウンロード状態付きの全モデル
catalog.modelForStyle(3)          // スタイルID からモデルを逆引き
catalog.downloadedSize()          // ダウンロード済みの合計サイズ(bytes)
```

### ダウンロードの進捗とストレージ管理

モデルは1件あたり数十MB(最大約130MB、全27モデルで約1.7GB)あります。

```kotlin
voicevox.downloadModel("0") { done, total ->
    // IOディスパッチャ上から高頻度に呼ばれる。UI 更新は自前でスロットルすること
}

voicevox.modelIdForStyle(3)    // スタイルID → モデルID(synthesis 用)
voicevox.downloadedSize("0")   // そのモデルのローカルサイズ(bytes)。未DLなら 0
voicevox.deleteModel("0")      // ロード済みならアンロードしてから削除。suspend
```

## 音声モデルのライセンス

- モデルのダウンロード・合成には `acceptLicense(modelId)` による**明示的な同意が必須**です
- 規約の提示 UI はアプリ側で実装してください(`example/` に同意ダイアログの実装例があります)
- 生成音声の公開・利用時は `creditText`(例: 「VOICEVOX:ずんだもん」)の**クレジット表記が必要**です
- 詳細は [docs/MODEL_LICENSING.md](../../docs/MODEL_LICENSING.md) を参照

## ライセンス

このパッケージのコードは MIT License です([LICENSE](LICENSE))。VOICEVOX CORE・音声モデルにはそれぞれの規約が適用されます。
