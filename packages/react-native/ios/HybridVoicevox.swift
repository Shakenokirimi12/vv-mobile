import AVFoundation
import Foundation
import NitroModules
// VoicevoxCore の Swift ソースは prepare-sources.sh により
// ios/VoicevoxCore/ にコピーされ、このターゲットへ直接コンパイルされる
// (別モジュールとしては存在しないため import 不要)。

/// Nitro HybridObject 実装。
/// packages/swift の `Voicevox` Facade を呼ぶだけの薄いグルー。
final class HybridVoicevox: HybridVoicevoxSpec {
    private var voicevox: Voicevox?
    private var player: AVAudioPlayer?

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

    func listModels() throws -> Promise<[VoicevoxModel]> {
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

    func playWav(wav: ArrayBuffer) throws -> Promise<Void> {
        // ArrayBuffer は JS スレッド外では寿命保証がないため、先にコピーする
        let data = wav.toData(copyIfNeeded: true)
        return Promise.async { @MainActor in
            let player = try AVAudioPlayer(data: data)
            self.player?.stop()
            self.player = player
            player.play()
        }
    }

    func stopPlayback() throws {
        player?.stop()
        player = nil
    }
}

private extension VoicevoxModelInfo {
    /// VoicevoxCore のモデル情報を Nitro 生成の構造体(VoicevoxModel)へ変換する。
    func toNitro() -> VoicevoxModel {
        VoicevoxModel(
            id: id,
            filename: filename,
            sizeBytes: Double(sizeBytes),
            downloadURL: downloadURL,
            vvmId: vvmId,
            domains: domains,
            characters: characters.map { character in
                VoicevoxCharacter(
                    name: character.name,
                    speakerUuid: character.speakerUuid,
                    creditText: character.creditText,
                    termsURL: character.termsURL,
                    styles: character.styles.map {
                        VoicevoxStyle(name: $0.name, id: Double($0.id), type: $0.type)
                    }
                )
            },
            isDownloaded: isDownloaded
        )
    }
}
