import Foundation

/// 音声モデル(.vvm)1件のメタデータ。licenses.json 由来。
public struct VoicevoxModelInfo: Codable, Identifiable, Sendable, Equatable {
    public struct Character: Codable, Sendable, Equatable {
        public struct Style: Codable, Sendable, Equatable {
            public let name: String
            public let id: UInt32
            /// スタイル種別。"talk" はテキスト読み上げ(synthesis で使用可)、
            /// "frame_decode" は歌唱合成用で synthesis では使えない。
            public let type: String
        }

        public let name: String
        public let speakerUuid: String
        /// 生成音声の利用時に必要なクレジット表記(例: "VOICEVOX:ずんだもん")。
        public let creditText: String
        /// キャラクター個別の利用規約URL。
        public let termsURL: String
        public let styles: [Style]

        /// テキスト読み上げに使えるスタイルのみ。
        public var talkStyles: [Style] { styles.filter { $0.type == "talk" } }
    }

    public let id: String
    public let filename: String
    public let sizeBytes: Int64
    public let downloadURL: String
    public let vvmId: String
    /// モデルが対応する合成ドメイン(例: ["talk"]、歌唱モデルは ["frame_decode"])。
    public let domains: [String]
    public let characters: [Character]

    /// ダウンロード済みかどうか(listModels() 時に付与)。
    public var isDownloaded: Bool = false

    /// テキスト読み上げ(synthesis)に対応したモデルかどうか。
    public var supportsTalk: Bool { domains.contains("talk") }

    private enum CodingKeys: String, CodingKey {
        case id, filename, sizeBytes, downloadURL, vvmId, domains, characters
    }
}

/// licenses.json 全体。
struct LicenseCatalog: Codable, Sendable {
    let termsVersion: String
    let termsURL: String
    let models: [VoicevoxModelInfo]

    static func bundled() throws -> LicenseCatalog {
        guard let url = Bundle.module.url(forResource: "licenses", withExtension: "json") else {
            throw VoicevoxError.missingResource("licenses.json")
        }
        return try JSONDecoder().decode(LicenseCatalog.self, from: Data(contentsOf: url))
    }
}
