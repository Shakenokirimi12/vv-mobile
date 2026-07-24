require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "RNVoicevox"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = "https://github.com/vv-mobile/vv-mobile"
  s.license      = "MIT"
  s.authors      = "vv-mobile"
  s.platforms    = { :ios => "15.0" }
  s.source       = { :git => "https://github.com/vv-mobile/vv-mobile.git", :tag => "react-native-v#{s.version}" }

  # RN グルー + packages/swift から複製した VoicevoxCore 実装
  # (ios/VoicevoxCore は scripts/prepare-sources.sh が配置する)
  s.source_files = [
    "ios/**/*.{swift,h,c}",
    "nitrogen/generated/ios/**/*.{swift,hpp,cpp}",
    "nitrogen/generated/shared/**/*.{hpp,cpp}",
  ]
  s.public_header_files = "ios/VoicevoxCore/CVoicevoxCore/include/*.h"
  s.preserve_paths = "ios/VoicevoxCore/CVoicevoxCore/include/module.modulemap"

  s.vendored_frameworks = [
    "ios/Frameworks/voicevox_core.xcframework",
    "ios/Frameworks/voicevox_onnxruntime.xcframework",
  ]

  s.resource_bundles = {
    "RNVoicevoxResources" => [
      "ios/Resources/licenses.json",
      "ios/Resources/open_jtalk_dic",
    ]
  }

  s.pod_target_xcconfig = {
    "SWIFT_INCLUDE_PATHS" => "$(PODS_TARGET_SRCROOT)/ios/VoicevoxCore/CVoicevoxCore/include",
    "DEFINES_MODULE" => "YES",
  }

  s.swift_version = "5.9"

  load File.join(__dir__, "nitrogen/generated/ios/RNVoicevox+autolinking.rb")
  add_nitrogen_files(s)

  s.dependency "React-Core"
  install_modules_dependencies(s)
end
