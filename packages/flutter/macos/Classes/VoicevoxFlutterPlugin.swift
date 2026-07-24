// FFI プラグインのため Dart 側から dart:ffi で直接ネイティブライブラリを呼ぶ。
// このファイルは CocoaPods プラグインの最小ソースとして存在する。
import FlutterMacOS
import Foundation

public class VoicevoxFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    // FFI プラグインのためメソッドチャンネル登録は不要。
  }
}
