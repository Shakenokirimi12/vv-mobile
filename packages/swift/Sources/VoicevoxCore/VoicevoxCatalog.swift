import Foundation

/// 音声モデルのカタログ(licenses.json)への軽量なアクセス。
///
/// `Voicevox` の初期化は ONNX Runtime のロードと Open JTalk 辞書の読み込みを伴うため、
/// キャラクター一覧やダウンロード状態を出したいだけの画面には重すぎる。
/// こちらは JSON を読むだけなので、そういう画面から同期的に使える。
///
/// ```swift
/// let catalog = try VoicevoxCatalog()
/// for model in catalog.models() {
///     print(model.characters.first?.name ?? "", model.isDownloaded)
/// }
/// ```
///
/// ダウンロード・合成には `Voicevox` が必要。
public struct VoicevoxCatalog: Sendable {
    private let catalog: LicenseCatalog
    private let modelsDir: URL

    /// - Parameter modelsDir: モデル保存先。nil なら `Voicevox` と同じ既定値。
    ///   `Voicevox` に別の保存先を渡している場合は、こちらにも同じものを渡すこと。
    public init(modelsDir: URL? = nil) throws {
        self.catalog = try LicenseCatalog.bundled()
        self.modelsDir = try modelsDir ?? Self.defaultModelsDirectory()
    }

    /// モデル保存先の既定値。
    public static func defaultModelsDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("VoicevoxCore/models", isDirectory: true)
    }

    /// 利用規約のバージョン。同意状態はこれとの組で永続化される。
    public var termsVersion: String { catalog.termsVersion }

    /// 全モデル共通の利用規約(VOICEVOX 音声モデル利用規約)のURL。
    public var termsURL: String { catalog.termsURL }

    /// 全モデルの一覧(ダウンロード状態付き)。
    public func models() -> [VoicevoxModelInfo] {
        catalog.models.map { model in
            var copy = model
            copy.isDownloaded = isDownloaded(modelId: model.id)
            return copy
        }
    }

    /// モデルID から引く。
    public func model(id: String) -> VoicevoxModelInfo? {
        models().first { $0.id == id }
    }

    /// スタイルID を含むモデル。
    ///
    /// VOICEVOX のスタイルID はモデルを跨いで一意なので、スタイルID だけを
    /// 保持しているアプリから合成対象のモデルを解決するのに使える。
    public func model(forStyle styleId: UInt32) -> VoicevoxModelInfo? {
        models().first { model in
            model.characters.contains { character in
                character.styles.contains { $0.id == styleId }
            }
        }
    }

    /// モデルのローカルパス。
    public func localURL(for modelId: String) -> URL? {
        guard let info = catalog.models.first(where: { $0.id == modelId }) else { return nil }
        return modelsDir.appendingPathComponent(info.filename)
    }

    /// ダウンロード済みか。
    public func isDownloaded(modelId: String) -> Bool {
        guard let url = localURL(for: modelId) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// ダウンロード済みモデルのローカルサイズ(bytes)。未ダウンロードなら 0。
    public func downloadedSize(modelId: String) -> Int64 {
        guard let url = localURL(for: modelId),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        else { return 0 }
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// ダウンロード済みモデルの合計サイズ(bytes)。
    public func downloadedSize() -> Int64 {
        catalog.models.reduce(0) { $0 + downloadedSize(modelId: $1.id) }
    }
}
