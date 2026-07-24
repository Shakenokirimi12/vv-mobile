import Foundation

/// モデル利用規約への同意状態を管理するゲート。
///
/// モデルのダウンロード・ロードは、対象モデルに対して `accept` 済みで
/// ない限り `VoicevoxError.licenseNotAccepted` で拒否される。
/// 同意状態は (modelId, termsVersion) の組で永続化されるため、
/// 利用規約のバージョンが上がると再同意が必要になる。
// UserDefaults はスレッド安全なため @unchecked Sendable とする。
public struct LicenseGate: @unchecked Sendable {
    private let defaults: UserDefaults
    private let termsVersion: String
    private static let key = "jp.voicevox.vv-mobile.acceptedLicenses"

    init(termsVersion: String, defaults: UserDefaults = .standard) {
        self.termsVersion = termsVersion
        self.defaults = defaults
    }

    private func storageValue(for modelId: String) -> String {
        "\(modelId)@\(termsVersion)"
    }

    /// モデルの利用規約に同意する。
    /// アプリ側は必ず利用者に規約(termsURL)を提示した上で呼ぶこと。
    public func accept(modelId: String) {
        var set = Set(defaults.stringArray(forKey: Self.key) ?? [])
        set.insert(storageValue(for: modelId))
        defaults.set(Array(set).sorted(), forKey: Self.key)
    }

    /// 同意を取り消す。
    public func revoke(modelId: String) {
        var set = Set(defaults.stringArray(forKey: Self.key) ?? [])
        set.remove(storageValue(for: modelId))
        defaults.set(Array(set).sorted(), forKey: Self.key)
    }

    /// 現在の規約バージョンで同意済みか。
    public func isAccepted(modelId: String) -> Bool {
        Set(defaults.stringArray(forKey: Self.key) ?? [])
            .contains(storageValue(for: modelId))
    }

    /// 未同意なら licenseNotAccepted を投げる。
    func require(modelId: String) throws {
        guard isAccepted(modelId: modelId) else {
            throw VoicevoxError.licenseNotAccepted(modelId: modelId)
        }
    }
}
