// FFI プラグインのため Dart 側から dart:ffi で直接ネイティブライブラリを呼ぶ。
// このファイルは SwiftPM ターゲットの最小ソースとして存在し、
// vendored xcframework をアプリへリンクさせる役割のみを持つ。
import Foundation

public enum VoicevoxFlutterPlugin {
    /// リンカがバイナリターゲットを削除しないよう参照を保持するダミー。
    public static let pluginName = "voicevox_flutter"
}
