// SwiftPM では CVoicevoxCore(正規化ヘッダのCモジュール)、
// CocoaPods(react-native-voicevox の vendored ビルド)では
// xcframework 内蔵の voicevox_core フレームワークモジュールを使う。
// どちらの環境でも「C API を提供するモジュールは1つだけ」にすることで
// 型解決の不一致を防ぐ。
#if canImport(CVoicevoxCore)
import CVoicevoxCore
#else
import voicevox_core
#endif
import Foundation

/// voicevox_core C API の薄いラッパー。
/// ONNX Runtime / Open JTalk / Synthesizer のライフサイクルを1つに束ねる。
///
/// スレッド安全性は voicevox_core 側が保証している(内部でロックされる)ため、
/// このクラスは `@unchecked Sendable` とし、複数タスクからの同時利用を許す。
public final class Synthesizer: @unchecked Sendable {
    private let synthesizer: OpaquePointer
    private let openJtalk: OpaquePointer
    private var loadedModelIds: Set<String> = []
    private let lock = NSLock()

    /// - Parameters:
    ///   - openJtalkDictDir: Open JTalk 辞書ディレクトリ。nil なら同梱辞書を使う。
    ///   - onnxruntimePath: (macOS/Linux のみ)ONNX Runtime 動的ライブラリのパス。
    ///     nil ならデフォルトのファイル名で探索する。
    public init(openJtalkDictDir: URL? = nil, onnxruntimePath: String? = nil) throws {
        let onnxruntime = try Self.loadOnnxruntime(path: onnxruntimePath)

        let dictDir: URL
        if let openJtalkDictDir {
            dictDir = openJtalkDictDir
        } else {
            guard let bundled = Bundle.module.url(forResource: "open_jtalk_dic", withExtension: nil) else {
                throw VoicevoxError.missingResource("open_jtalk_dic")
            }
            dictDir = bundled
        }

        var ojt: OpaquePointer?
        try check(voicevox_open_jtalk_rc_new(dictDir.path, &ojt))
        guard let ojt else { throw VoicevoxError.missingResource("OpenJtalkRc") }

        var synth: OpaquePointer?
        let options = voicevox_make_default_initialize_options()
        let result = voicevox_synthesizer_new(onnxruntime, ojt, options, &synth)
        guard result == 0, let synth else {
            voicevox_open_jtalk_rc_delete(ojt)
            let message = String(cString: voicevox_error_result_to_message(result))
            throw VoicevoxError.core(code: result, message: message)
        }

        self.openJtalk = ojt
        self.synthesizer = synth
    }

    deinit {
        voicevox_synthesizer_delete(synthesizer)
        voicevox_open_jtalk_rc_delete(openJtalk)
    }

    private static func loadOnnxruntime(path: String?) throws -> OpaquePointer {
        var onnxruntime: OpaquePointer?
        #if os(iOS)
        // iOS はリンク時動的リンク(VOICEVOX_LINK_ONNXRUNTIME)。
        try check(voicevox_onnxruntime_init_once(&onnxruntime))
        #else
        // macOS 等は実行時ロード(VOICEVOX_LOAD_ONNXRUNTIME)。
        var options = voicevox_make_default_load_onnxruntime_options()
        if let path {
            try path.withCString { cstr in
                options.filename = cstr
                return try check(voicevox_onnxruntime_load_once(options, &onnxruntime))
            }
        } else {
            try check(voicevox_onnxruntime_load_once(options, &onnxruntime))
        }
        #endif
        guard let onnxruntime else { throw VoicevoxError.missingResource("VoicevoxOnnxruntime") }
        return onnxruntime
    }

    /// .vvm ファイルをロードする。同一モデルの二重ロードは無視される。
    public func loadVoiceModel(at url: URL, modelId: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !loadedModelIds.contains(modelId) else { return }

        var model: OpaquePointer?
        try check(voicevox_voice_model_file_open(url.path, &model))
        guard let model else { throw VoicevoxError.missingResource(url.path) }
        defer { voicevox_voice_model_file_delete(model) }

        try check(voicevox_synthesizer_load_voice_model(synthesizer, model))
        loadedModelIds.insert(modelId)
    }

    /// モデルがロード済みかどうか。
    public func isLoaded(modelId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return loadedModelIds.contains(modelId)
    }

    /// テキストから WAV を合成する。
    public func tts(text: String, styleId: UInt32) throws -> Data {
        var wavLength: UInt = 0
        var wav: UnsafeMutablePointer<UInt8>?
        let options = voicevox_make_default_tts_options()
        try check(voicevox_synthesizer_tts(synthesizer, text, styleId, options, &wavLength, &wav))
        guard let wav else { throw VoicevoxError.missingResource("wav output") }
        defer { voicevox_wav_free(wav) }
        return Data(bytes: wav, count: Int(wavLength))
    }

    /// voicevox_core のバージョン文字列。
    public static var coreVersion: String {
        String(cString: voicevox_get_version())
    }
}
