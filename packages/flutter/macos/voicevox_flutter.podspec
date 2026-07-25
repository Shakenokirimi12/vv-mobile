#
# voicevox_flutter (macOS)
# vendored xcframework は ../scripts/prepare-binaries.sh(モノレポ開発時)か
# prepare_command の fetch-native.sh(pub.dev 取得時)が Frameworks/ に配置する。
#
Pod::Spec.new do |s|
  s.name             = 'voicevox_flutter'
  s.version          = '0.1.0'
  s.summary          = 'VOICEVOX CORE binding for Flutter.'
  s.description      = <<-DESC
VOICEVOX CORE binding for Flutter (FFI). Text-to-speech synthesis with runtime
voice model download and per-character license gating.
                       DESC
  s.homepage         = 'https://github.com/shakenokirimi12/vv-mobile'
  s.license          = { :type => 'MIT' }
  s.author           = { 'vv-mobile' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '13.0'

  s.vendored_frameworks = 'Frameworks/voicevox_core.xcframework',
                          'Frameworks/voicevox_onnxruntime.xcframework'

  # pub.dev 配布物には xcframework を含めない(サイズ制限のため)。
  # 未配置ならここで公式リリースから取得する(モノレポ開発時は既に
  # scripts/prepare-binaries.sh が配置済みなのでスキップされる)。
  s.prepare_command = 'bash ../scripts/fetch-native.sh macos ./Frameworks'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
