package com.voicevox

import com.margelo.nitro.NitroModules
import com.margelo.nitro.core.ArrayBuffer
import com.margelo.nitro.core.Promise
import com.margelo.nitro.voicevox.DownloadResult
import com.margelo.nitro.voicevox.HybridVoicevoxSpec
import com.margelo.nitro.voicevox.VoicevoxCharacter
import com.margelo.nitro.voicevox.VoicevoxModelInfo
import com.margelo.nitro.voicevox.VoicevoxStyle
import jp.voicevox.android.Voicevox

/**
 * Nitro HybridObject 実装。
 * packages/android の [Voicevox] Facade を呼ぶだけの薄いグルー。
 */
class HybridVoicevox : HybridVoicevoxSpec() {
    private var voicevox: Voicevox? = null

    private fun requireVoicevox(): Voicevox =
        voicevox ?: throw IllegalStateException("call initialize() first")

    override fun initialize(maxConcurrentDownloads: Double): Promise<Unit> =
        Promise.async {
            val context = NitroModules.applicationContext
                ?: throw IllegalStateException("no application context")
            voicevox = Voicevox.create(
                context = context,
                maxConcurrentDownloads = maxConcurrentDownloads.toInt(),
            )
        }

    override fun listModels(): Promise<Array<VoicevoxModelInfo>> {
        val vv = requireVoicevox()
        return Promise.async {
            vv.listModels().map { it.toNitro() }.toTypedArray()
        }
    }

    override fun getTermsURL(): String = requireVoicevox().termsURL

    override fun acceptLicense(modelId: String) {
        requireVoicevox().acceptLicense(modelId)
    }

    override fun isLicenseAccepted(modelId: String): Boolean =
        requireVoicevox().isLicenseAccepted(modelId)

    override fun downloadModel(id: String): Promise<Unit> {
        val vv = requireVoicevox()
        return Promise.async { vv.downloadModel(id) }
    }

    override fun downloadModels(ids: Array<String>): Promise<Array<DownloadResult>> {
        val vv = requireVoicevox()
        return Promise.async {
            val results = vv.downloadModels(ids.toList())
            ids.map { id ->
                DownloadResult(
                    modelId = id,
                    error = results[id]?.exceptionOrNull()?.toString(),
                )
            }.toTypedArray()
        }
    }

    override fun downloadAllModels(): Promise<Array<DownloadResult>> {
        val vv = requireVoicevox()
        return Promise.async {
            vv.downloadAllModels().map { (id, result) ->
                DownloadResult(modelId = id, error = result.exceptionOrNull()?.toString())
            }.toTypedArray()
        }
    }

    override fun synthesis(text: String, modelId: String, styleId: Double?): Promise<ArrayBuffer> {
        val vv = requireVoicevox()
        return Promise.async {
            val wav = vv.synthesis(text, modelId, styleId?.toInt())
            ArrayBuffer.copy(java.nio.ByteBuffer.wrap(wav))
        }
    }
}

/** voicevox-core-android のモデル情報を Nitro 生成の構造体へ変換する。 */
private fun jp.voicevox.android.VoicevoxModelInfo.toNitro(): VoicevoxModelInfo =
    VoicevoxModelInfo(
        id = id,
        filename = filename,
        sizeBytes = sizeBytes.toDouble(),
        downloadURL = downloadURL,
        vvmId = vvmId,
        characters = characters.map { c ->
            VoicevoxCharacter(
                name = c.name,
                speakerUuid = c.speakerUuid,
                creditText = c.creditText,
                termsURL = c.termsURL,
                styles = c.styles.map { VoicevoxStyle(it.name, it.id.toDouble()) }
                    .toTypedArray(),
            )
        }.toTypedArray(),
        isDownloaded = isDownloaded,
    )
