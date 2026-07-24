// Synthesizer.swift と同様、C API モジュールはビルド環境ごとに1つに揃える。
#if canImport(CVoicevoxCore)
import CVoicevoxCore
#else
import voicevox_core
#endif
import Foundation

/// voicevox_core の結果コードおよびパッケージ固有の失敗を表すエラー。
public enum VoicevoxError: Error, LocalizedError, Equatable {
    /// voicevox_core の C API がエラーコードを返した。
    case core(code: Int32, message: String)
    /// モデルの利用規約に未同意のまま取得・ロードしようとした。
    case licenseNotAccepted(modelId: String)
    /// 未ダウンロードのモデルで合成しようとした。
    case modelNotDownloaded(modelId: String)
    /// licenses.json に存在しないモデルIDを指定した。
    case unknownModel(modelId: String)
    /// モデルのダウンロードに失敗した。
    case downloadFailed(modelId: String, underlying: String)
    /// 同梱リソース(辞書・licenses.json)が見つからない。
    case missingResource(String)

    public var errorDescription: String? {
        switch self {
        case let .core(code, message):
            return "voicevox_core error \(code): \(message)"
        case let .licenseNotAccepted(modelId):
            return "モデル \(modelId) の利用規約に同意していません。LicenseGate.accept で同意してください"
        case let .modelNotDownloaded(modelId):
            return "モデル \(modelId) は未ダウンロードです。downloadModel を先に呼んでください"
        case let .unknownModel(modelId):
            return "不明なモデルID: \(modelId)"
        case let .downloadFailed(modelId, underlying):
            return "モデル \(modelId) のダウンロードに失敗しました: \(underlying)"
        case let .missingResource(name):
            return "同梱リソースが見つかりません: \(name)"
        }
    }
}

/// C API の結果コードを検査し、成功以外なら VoicevoxError を投げる。
/// (VoicevoxResultCode は enum タグと typedef が同名で曖昧になるため Int32 を使う)
@inline(__always)
func check(_ code: Int32) throws {
    guard code == 0 else {
        let message = String(cString: voicevox_error_result_to_message(code))
        throw VoicevoxError.core(code: code, message: message)
    }
}
