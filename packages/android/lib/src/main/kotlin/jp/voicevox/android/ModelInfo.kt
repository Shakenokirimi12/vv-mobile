package jp.voicevox.android

import kotlinx.serialization.Serializable

/** 音声モデル(.vvm)1件のメタデータ。licenses.json 由来。 */
@Serializable
data class VoicevoxModelInfo(
    val id: String,
    val filename: String,
    val sizeBytes: Long,
    val downloadURL: String,
    val vvmId: String,
    val characters: List<Character>,
    /** listModels() 時に付与されるダウンロード状態。 */
    val isDownloaded: Boolean = false,
) {
    @Serializable
    data class Character(
        val name: String,
        val speakerUuid: String,
        /** 生成音声の利用時に必要なクレジット表記(例: "VOICEVOX:ずんだもん")。 */
        val creditText: String,
        /** キャラクター個別の利用規約URL。 */
        val termsURL: String,
        val styles: List<Style>,
    ) {
        @Serializable
        data class Style(val name: String, val id: Int)
    }
}

/** licenses.json 全体。 */
@Serializable
internal data class LicenseCatalog(
    val termsVersion: String,
    val termsURL: String,
    val models: List<VoicevoxModelInfo>,
)
