import Foundation

/// .vvm モデルファイルの実行時ダウンロードとローカルキャッシュ管理。
public struct ModelManager: Sendable {
    let catalog: LicenseCatalog
    let gate: LicenseGate
    private let modelsDir: URL

    init(catalog: LicenseCatalog, gate: LicenseGate, modelsDir: URL? = nil) throws {
        self.catalog = catalog
        self.gate = gate
        if let modelsDir {
            self.modelsDir = modelsDir
        } else {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.modelsDir = base.appendingPathComponent("VoicevoxCore/models", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.modelsDir, withIntermediateDirectories: true)
    }

    func info(for modelId: String) throws -> VoicevoxModelInfo {
        guard let info = catalog.models.first(where: { $0.id == modelId }) else {
            throw VoicevoxError.unknownModel(modelId: modelId)
        }
        return info
    }

    /// モデルのローカルパス。
    public func localURL(for modelId: String) throws -> URL {
        modelsDir.appendingPathComponent(try info(for: modelId).filename)
    }

    /// ダウンロード済みか。
    public func isDownloaded(modelId: String) -> Bool {
        guard let url = try? localURL(for: modelId) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// 1モデルをダウンロードする(同意必須)。
    /// 既にダウンロード済みなら何もしない。
    public func download(modelId: String, session: URLSession = .shared) async throws {
        try gate.require(modelId: modelId)
        let info = try info(for: modelId)
        let dest = try localURL(for: modelId)
        guard !FileManager.default.fileExists(atPath: dest.path) else { return }

        guard let url = URL(string: info.downloadURL) else {
            throw VoicevoxError.downloadFailed(modelId: modelId, underlying: "invalid URL")
        }
        do {
            let (tmp, response) = try await session.download(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw VoicevoxError.downloadFailed(modelId: modelId, underlying: "HTTP \(status)")
            }
            // 別タスクが先に完了していた場合は置き換えない
            if !FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.moveItem(at: tmp, to: dest)
            }
        } catch let error as VoicevoxError {
            throw error
        } catch {
            throw VoicevoxError.downloadFailed(modelId: modelId, underlying: String(describing: error))
        }
    }

    /// ダウンロード済みモデルを削除する。
    public func remove(modelId: String) throws {
        let url = try localURL(for: modelId)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
