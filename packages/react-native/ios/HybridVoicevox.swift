import Foundation
import NitroModules
import VoicevoxCore

/// Nitro HybridObject 実装。
/// packages/swift の `Voicevox` Facade を呼ぶだけの薄いグルー。
final class HybridVoicevox: HybridVoicevoxSpec {
    private var voicevox: Voicevox?

    private func requireVoicevox() throws -> Voicevox {
        guard let voicevox else {
            throw RuntimeError.error(withMessage: "call initialize() first")
        }
        return voicevox
    }

    func initialize(maxConcurrentDownloads: Double) throws -> Promise<Void> {
        Promise.async { [weak self] in
            let voicevox = try Voicevox(
                maxConcurrentDownloads: Int(maxConcurrentDownloads)
            )
            self?.voicevox = voicevox
        }
    }

    func listModels() throws -> Promise<[VoicevoxModelInfo]> {
        let voicevox = try requireVoicevox()
        return Promise.async {
            await voicevox.listModels().map { $0.toNitro() }
        }
    }

    func getTermsURL() throws -> String {
        try requireVoicevox().termsURL
    }

    func acceptLicense(modelId: String) throws {
        try requireVoicevox().acceptLicense(modelId: modelId)
    }

    func isLicenseAccepted(modelId: String) throws -> Bool {
        try requireVoicevox().isLicenseAccepted(modelId: modelId)
    }

    func downloadModel(id: String) throws -> Promise<Void> {
        let voicevox = try requireVoicevox()
        return Promise.async {
            try await voicevox.downloadModel(id: id)
        }
    }

    func downloadModels(ids: [String]) throws -> Promise<[DownloadResult]> {
        let voicevox = try requireVoicevox()
        return Promise.async {
            let results = await voicevox.downloadModels(ids: ids)
            return ids.map { id in
                switch results[id] {
                case .success, .none:
                    return DownloadResult(modelId: id, error: nil)
                case .failure(let error):
                    return DownloadResult(modelId: id, error: String(describing: error))
                }
            }
        }
    }

    func downloadAllModels() throws -> Promise<[DownloadResult]> {
        let voicevox = try requireVoicevox()
        return Promise.async {
            let results = await voicevox.downloadAllModels()
            return results.map { id, result in
                switch result {
                case .success:
                    return DownloadResult(modelId: id, error: nil)
                case .failure(let error):
                    return DownloadResult(modelId: id, error: String(describing: error))
                }
            }
        }
    }

    func synthesis(text: String, modelId: String, styleId: Double?) throws -> Promise<ArrayBuffer> {
        let voicevox = try requireVoicevox()
        return Promise.async {
            let wav = try await voicevox.synthesis(
                text: text,
                modelId: modelId,
                styleId: styleId.map { UInt32($0) }
            )
            return try ArrayBuffer.copy(data: wav)
        }
    }
}

private extension VoicevoxCore.VoicevoxModelInfo {
    /// VoicevoxCore のモデル情報を Nitro 生成の構造体へ変換する。
    func toNitro() -> VoicevoxModelInfo {
        VoicevoxModelInfo(
            id: id,
            filename: filename,
            sizeBytes: Double(sizeBytes),
            downloadURL: downloadURL,
            vvmId: vvmId,
            characters: characters.map { character in
                VoicevoxCharacter(
                    name: character.name,
                    speakerUuid: character.speakerUuid,
                    creditText: character.creditText,
                    termsURL: character.termsURL,
                    styles: character.styles.map {
                        VoicevoxStyle(name: $0.name, id: Double($0.id))
                    }
                )
            },
            isDownloaded: isDownloaded
        )
    }
}
