import Foundation

/// 高レベル Facade。通常の利用はこのクラスだけで完結する。
///
/// ```swift
/// let voicevox = try await Voicevox()
///
/// // 1. モデル一覧
/// let models = try await voicevox.listModels()
///
/// // 2. 利用規約に同意してダウンロード(個別 or 一括)
/// voicevox.acceptLicense(modelId: "0")
/// try await voicevox.downloadModel(id: "0")
///
/// // 3. 合成
/// let wav = try await voicevox.synthesis(text: "こんにちは", modelId: "0")
/// ```
public actor Voicevox {
    private let synthesizer: Synthesizer
    private let manager: ModelManager
    private let catalog: LicenseCatalog
    /// モデルダウンロードの同時実行数上限。
    private let maxConcurrentDownloads: Int

    public let gate: LicenseGate

    /// - Parameters:
    ///   - openJtalkDictDir: Open JTalk 辞書ディレクトリ(nil なら同梱辞書)。
    ///   - onnxruntimePath: macOS 等での ONNX Runtime dylib パス(nil なら既定探索)。
    ///   - modelsDir: モデル保存先(nil なら Application Support)。
    ///   - maxConcurrentDownloads: 並列ダウンロードの同時実行数(既定4)。
    public init(
        openJtalkDictDir: URL? = nil,
        onnxruntimePath: String? = nil,
        modelsDir: URL? = nil,
        maxConcurrentDownloads: Int = 4
    ) throws {
        let catalog = try LicenseCatalog.bundled()
        let gate = LicenseGate(termsVersion: catalog.termsVersion)
        self.catalog = catalog
        self.gate = gate
        self.manager = try ModelManager(catalog: catalog, gate: gate, modelsDir: modelsDir)
        self.synthesizer = try Synthesizer(
            openJtalkDictDir: openJtalkDictDir,
            onnxruntimePath: onnxruntimePath
        )
        self.maxConcurrentDownloads = max(1, maxConcurrentDownloads)
    }

    // MARK: - モデル一覧

    /// 利用可能な全モデルの一覧(ダウンロード状態付き)。
    public func listModels() -> [VoicevoxModelInfo] {
        catalog.models.map { model in
            var m = model
            m.isDownloaded = manager.isDownloaded(modelId: model.id)
            return m
        }
    }

    /// 全モデル共通の利用規約(VOICEVOX 音声モデル利用規約)のURL。
    public nonisolated var termsURL: String { catalog.termsURL }

    // MARK: - ライセンス同意

    /// モデルの利用規約に同意する。アプリ側は規約を提示した上で呼ぶこと。
    public nonisolated func acceptLicense(modelId: String) {
        gate.accept(modelId: modelId)
    }

    /// 同意状態を確認する。
    public nonisolated func isLicenseAccepted(modelId: String) -> Bool {
        gate.isAccepted(modelId: modelId)
    }

    // MARK: - ダウンロード

    /// 1モデルをダウンロードする(要同意)。ダウンロード済みなら何もしない。
    public func downloadModel(id: String) async throws {
        try await manager.download(modelId: id)
    }

    /// 複数モデルを並列ダウンロードする。
    /// - Returns: モデルIDごとの成否。一部失敗でも throw せず結果で返す。
    @discardableResult
    public func downloadModels(ids: [String]) async -> [String: Result<Void, VoicevoxError>] {
        let semaphore = AsyncSemaphore(value: maxConcurrentDownloads)
        let manager = self.manager
        return await withTaskGroup(
            of: (String, Result<Void, VoicevoxError>).self,
            returning: [String: Result<Void, VoicevoxError>].self
        ) { group in
            for id in ids {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    do {
                        try await manager.download(modelId: id)
                        return (id, .success(()))
                    } catch let error as VoicevoxError {
                        return (id, .failure(error))
                    } catch {
                        return (id, .failure(.downloadFailed(modelId: id, underlying: String(describing: error))))
                    }
                }
            }
            var results: [String: Result<Void, VoicevoxError>] = [:]
            for await (id, result) in group {
                results[id] = result
            }
            return results
        }
    }

    /// 全モデルを一括ダウンロードする(全モデルへの同意が必要)。
    @discardableResult
    public func downloadAllModels() async -> [String: Result<Void, VoicevoxError>] {
        await downloadModels(ids: catalog.models.map(\.id))
    }

    // MARK: - 合成

    /// テキストから音声(WAV)を合成する。
    ///
    /// モデルが未ダウンロードの場合は `modelNotDownloaded` を投げる
    /// (暗黙のダウンロードは行わない)。未ロードならロードしてから合成する。
    /// - Parameters:
    ///   - text: 読み上げるテキスト。
    ///   - modelId: モデルID(`listModels()` の `id`)。
    ///   - styleId: スタイルID。nil ならモデル先頭キャラクターの先頭スタイル。
    public func synthesis(text: String, modelId: String, styleId: UInt32? = nil) async throws -> Data {
        let info = try manager.info(for: modelId)
        guard manager.isDownloaded(modelId: modelId) else {
            throw VoicevoxError.modelNotDownloaded(modelId: modelId)
        }
        try gate.require(modelId: modelId)

        if !synthesizer.isLoaded(modelId: modelId) {
            try synthesizer.loadVoiceModel(at: manager.localURL(for: modelId), modelId: modelId)
        }

        let style = styleId ?? info.characters.first?.styles.first?.id ?? 0
        let synthesizer = self.synthesizer
        // 合成はCPU負荷が高いのでactorの外(バックグラウンド)で実行する
        return try await Task.detached(priority: .userInitiated) {
            try synthesizer.tts(text: text, styleId: style)
        }.value
    }
}
