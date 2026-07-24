#import "VoicevoxFlutterPlugin.h"

@implementation VoicevoxFlutterPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  // FFI プラグインのためメソッドチャンネル登録は不要。
  // このクラスは登録機構(GeneratedPluginRegistrant)から呼ばれる
  // エントリポイントとしてのみ存在する。
}

@end
