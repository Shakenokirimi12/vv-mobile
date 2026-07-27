package jp.voicevox.android

import android.content.Context
import java.io.File
import kotlinx.serialization.json.Json

/**
 * 音声モデルのカタログ(licenses.json)への軽量なアクセス。
 *
 * [Voicevox.create] は ONNX Runtime のロードと Open JTalk 辞書(約100MB)の展開を伴い、
 * 初回は数秒〜数十秒かかる。キャラクター一覧やダウンロード状態を表示したいだけの画面で
 * それを待つ必要はないので、ネイティブ初期化なしで読めるカタログを分けてある。
 *
 * ```kotlin
 * val catalog = VoicevoxCatalog.load(context)
 * catalog.models().forEach { println("${it.characters.first().name} ${it.isDownloaded}") }
 * ```
 *
 * ダウンロード・合成には [Voicevox] が必要。
 */
class VoicevoxCatalog private constructor(
    private val catalog: LicenseCatalog,
    private val modelsDir: File,
) {
    companion object {
        /**
         * assets の licenses.json を読み込む。
         *
         * @param modelsDir モデル保存先(null なら [defaultModelsDir])。
         *   [Voicevox.create] に渡したものと揃えること。
         */
        fun load(context: Context, modelsDir: File? = null): VoicevoxCatalog {
            val appContext = context.applicationContext
            return VoicevoxCatalog(parse(appContext), modelsDir ?: defaultModelsDir(appContext))
        }

        /** モデル保存先の既定値。 */
        fun defaultModelsDir(context: Context): File =
            File(context.applicationContext.filesDir, "voicevox/models")

        internal fun parse(context: Context): LicenseCatalog =
            Json.decodeFromString(
                context.assets.open("licenses.json").bufferedReader().use { it.readText() }
            )
    }

    /** 利用規約のバージョン。同意状態はこれとの組で永続化される。 */
    val termsVersion: String get() = catalog.termsVersion

    /** 全モデル共通の利用規約(VOICEVOX 音声モデル利用規約)のURL。 */
    val termsURL: String get() = catalog.termsURL

    /** 全モデルの一覧(ダウンロード状態付き)。 */
    fun models(): List<VoicevoxModelInfo> =
        catalog.models.map { it.copy(isDownloaded = isDownloaded(it.id)) }

    /** モデルID から引く。存在しなければ null。 */
    fun model(id: String): VoicevoxModelInfo? =
        catalog.models.firstOrNull { it.id == id }?.copy(isDownloaded = isDownloaded(id))

    /**
     * スタイルID を含むモデルを引く。存在しなければ null。
     *
     * VOICEVOX のスタイルID はモデルを跨いで一意なので、
     * スタイルID だけを保持しているアプリから合成対象のモデルを解決するのに使える。
     */
    fun modelForStyle(styleId: Int): VoicevoxModelInfo? =
        catalog.models
            .firstOrNull { model -> model.characters.any { c -> c.styles.any { it.id == styleId } } }
            ?.let { it.copy(isDownloaded = isDownloaded(it.id)) }

    /** ダウンロード済みか。 */
    fun isDownloaded(modelId: String): Boolean = localFile(modelId)?.exists() == true

    /** ダウンロード済みモデルのローカルサイズ(bytes)。未ダウンロードなら 0。 */
    fun downloadedSize(modelId: String): Long =
        localFile(modelId)?.takeIf { it.exists() }?.length() ?: 0L

    /** ダウンロード済みモデルの合計サイズ(bytes)。 */
    fun downloadedSize(): Long = catalog.models.sumOf { downloadedSize(it.id) }

    private fun localFile(modelId: String): File? =
        catalog.models.firstOrNull { it.id == modelId }?.let { File(modelsDir, it.filename) }
}
