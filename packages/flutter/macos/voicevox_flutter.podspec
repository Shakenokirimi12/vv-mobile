#
# voicevox_flutter (macOS)
# vendored xcframework は ../scripts/prepare-binaries.sh が Frameworks/ に配置する。
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

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
