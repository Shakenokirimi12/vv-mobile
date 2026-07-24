package jp.voicevox.android

/** vv-mobile パッケージ固有の失敗。 */
sealed class VoicevoxException(message: String) : Exception(message) {
    /** モデルの利用規約に未同意のまま取得・ロードしようとした。 */
    class LicenseNotAccepted(val modelId: String) :
        VoicevoxException("モデル $modelId の利用規約に同意していません。LicenseGate.accept で同意してください")

    /** 未ダウンロードのモデルで合成しようとした。 */
    class ModelNotDownloaded(val modelId: String) :
        VoicevoxException("モデル $modelId は未ダウンロードです。downloadModel を先に呼んでください")

    /** licenses.json に存在しないモデルID。 */
    class UnknownModel(val modelId: String) :
        VoicevoxException("不明なモデルID: $modelId")

    /** ダウンロード失敗。 */
    class DownloadFailed(val modelId: String, cause: String) :
        VoicevoxException("モデル $modelId のダウンロードに失敗しました: $cause")
}
