import Foundation

/// .vvm モデルファイルの実行時ダウンロードとローカルキャッシュ管理。
public struct ModelManager: Sendable {
    let catalog: LicenseCatalog
    let gate: LicenseGate
    private let modelsDir: URL

    /// 進捗つきダウンロード時の書き出し単位。
    private let bufferSize = 64 * 1024

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
    ///
    /// - Parameter onProgress: 進捗コールバック。(受信済みbytes, 全体bytes)。
    ///   Content-Length が得られない場合は licenses.json の sizeBytes を全体サイズとして渡す。
    ///   nil を渡すと、進捗を追わない軽い経路(`URLSession.download`)を使う。
    public func download(
        modelId: String,
        session: URLSession = .shared,
        onProgress: (@Sendable (Int64, Int64) -> Void)? = nil
    ) async throws {
        try gate.require(modelId: modelId)
        let info = try info(for: modelId)
        let dest = try localURL(for: modelId)
        guard !FileManager.default.fileExists(atPath: dest.path) else { return }

        guard let url = URL(string: info.downloadURL) else {
            throw VoicevoxError.downloadFailed(modelId: modelId, underlying: "invalid URL")
        }
        do {
            let tmp: URL
            if let onProgress {
                tmp = try await downloadReporting(
                    url: url, modelId: modelId, session: session,
                    fallbackTotal: info.sizeBytes, onProgress: onProgress
                )
            } else {
                let (downloaded, response) = try await session.download(from: url)
                try Self.validate(response, modelId: modelId)
                tmp = downloaded
            }
            // 別タスクが先に完了していた場合は置き換えない
            if !FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.moveItem(at: tmp, to: dest)
            } else {
                try? FileManager.default.removeItem(at: tmp)
            }
        } catch let error as VoicevoxError {
            throw error
        } catch {
            throw VoicevoxError.downloadFailed(modelId: modelId, underlying: String(describing: error))
        }
    }

    /// バイト列を流しながら一時ファイルに書き出し、進捗を報告する。
    private func downloadReporting(
        url: URL,
        modelId: String,
        session: URLSession,
        fallbackTotal: Int64,
        onProgress: @Sendable (Int64, Int64) -> Void
    ) async throws -> URL {
        let (bytes, response) = try await session.bytes(from: url)
        try Self.validate(response, modelId: modelId)

        let total = response.expectedContentLength > 0 ? response.expectedContentLength : fallbackTotal
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("vvm-\(UUID().uuidString).part")
        FileManager.default.createFile(atPath: tmp.path, contents: nil)

        let handle = try FileHandle(forWritingTo: tmp)
        defer { try? handle.close() }

        onProgress(0, total)
        // 1バイトずつ書くと遅すぎるので、64KB 単位でまとめて書き出す
        var buffer = Data(capacity: bufferSize)
        var written: Int64 = 0
        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= bufferSize {
                try handle.write(contentsOf: buffer)
                written += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                onProgress(written, total)
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            written += Int64(buffer.count)
        }
        onProgress(written, total)
        return tmp
    }

    private static func validate(_ response: URLResponse, modelId: String) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw VoicevoxError.downloadFailed(modelId: modelId, underlying: "HTTP \(status)")
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
