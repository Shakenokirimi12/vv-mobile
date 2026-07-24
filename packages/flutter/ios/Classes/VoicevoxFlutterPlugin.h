// FFI プラグインのため Dart 側から dart:ffi で直接ネイティブライブラリを呼ぶ。
// このファイルは CocoaPods プラグインの最小ソースとして存在する。
#import <Flutter/Flutter.h>

@interface VoicevoxFlutterPlugin : NSObject <FlutterPlugin>
@end
