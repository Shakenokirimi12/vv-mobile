package jp.voicevox.android

import java.io.File
import java.io.InputStream
import java.io.OutputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request

/** .vvm モデルファイルの実行時ダウンロードとローカルキャッシュ管理。 */
class ModelManager internal constructor(
    private val catalog: LicenseCatalog,
    private val gate: LicenseGate,
    private val modelsDir: File,
    private val client: OkHttpClient = OkHttpClient(),
) {
    init {
        modelsDir.mkdirs()
    }

    internal fun info(modelId: String): VoicevoxModelInfo =
        catalog.models.firstOrNull { it.id == modelId }
            ?: throw VoicevoxException.UnknownModel(modelId)

    /** モデルのローカルパス。 */
    fun localFile(modelId: String): File = File(modelsDir, info(modelId).filename)

    /** ダウンロード済みか。 */
    fun isDownloaded(modelId: String): Boolean = localFile(modelId).exists()

    /**
     * 1モデルをダウンロードする(要同意)。ダウンロード済みなら何もしない。
     *
     * @param onProgress 進捗コールバック。(受信済みbytes, 全体bytes)。
     *   Content-Length が得られない場合は licenses.json の sizeBytes を全体サイズとして渡す。
     */
    suspend fun download(
        modelId: String,
        onProgress: ((downloadedBytes: Long, totalBytes: Long) -> Unit)? = null,
    ) {
        gate.require(modelId)
        val info = info(modelId)
        val dest = localFile(modelId)
        if (dest.exists()) return

        withContext(Dispatchers.IO) {
            val request = Request.Builder().url(info.downloadURL).build()
            try {
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        throw VoicevoxException.DownloadFailed(modelId, "HTTP ${response.code}")
                    }
                    val body = response.body
                        ?: throw VoicevoxException.DownloadFailed(modelId, "empty body")
                    val total = body.contentLength().takeIf { it > 0 } ?: info.sizeBytes
                    val tmp = File.createTempFile("vvm-", ".part", modelsDir)
                    try {
                        tmp.outputStream().use { out ->
                            if (onProgress == null) {
                                body.byteStream().copyTo(out)
                            } else {
                                copyReporting(body.byteStream(), out, total, onProgress)
                            }
                        }
                        // 別コルーチンが先に完了していた場合は置き換えない
                        if (!dest.exists()) {
                            if (!tmp.renameTo(dest)) {
                                tmp.copyTo(dest, overwrite = false)
                            }
                        }
                    } finally {
                        tmp.delete()
                    }
                }
            } catch (e: VoicevoxException) {
                throw e
            } catch (e: Exception) {
                throw VoicevoxException.DownloadFailed(modelId, e.toString())
            }
        }
    }

    private fun copyReporting(
        input: InputStream,
        output: OutputStream,
        total: Long,
        onProgress: (Long, Long) -> Unit,
    ) {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var downloaded = 0L
        onProgress(0L, total)
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            output.write(buffer, 0, read)
            downloaded += read
            onProgress(downloaded, total)
        }
    }

    /** ダウンロード済みモデルを削除する。 */
    fun remove(modelId: String) {
        localFile(modelId).delete()
    }
}
