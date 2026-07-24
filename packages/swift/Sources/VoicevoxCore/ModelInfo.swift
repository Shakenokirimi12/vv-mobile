import Foundation

/// 音声モデル(.vvm)1件のメタデータ。licenses.json 由来。
public struct VoicevoxModelInfo: Codable, Identifiable, Sendable, Equatable {
    public struct Character: Codable, Sendable, Equatable {
        public struct Style: Codable, Sendable, Equatable {
            public let name: String
            public let id: UInt32
        }

        public let name: String
        public let speakerUuid: String
        /// 生成音声の利用時に必要なクレジット表記(例: "VOICEVOX:ずんだもん")。
        public let creditText: String
        /// キャラクター個別の利用規約URL。
        public let termsURL: String
        public let styles: [Style]
    }

    public let id: String
    public let filename: String
    public let sizeBytes: Int64
    public let downloadURL: String
    public let vvmId: String
    public let characters: [Character]

    /// ダウンロード済みかどうか(listModels() 時に付与)。
    public var isDownloaded: Bool = false

    private enum CodingKeys: String, CodingKey {
        case id, filename, sizeBytes, downloadURL, vvmId, characters
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
