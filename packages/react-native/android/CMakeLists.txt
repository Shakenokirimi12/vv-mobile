# react-native-voicevox (Android C++ / Nitro Modules)
# nitro.json の androidCxxLibName に合わせてライブラリ名は RNVoicevox。
cmake_minimum_required(VERSION 3.22.1)
project(RNVoicevox)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(RNVoicevox SHARED
  src/main/cpp/cpp-adapter.cpp
)

# nitrogen 生成ソース・依存の取り込み(OnLoad / Spec / fbjni / NitroModules)
include(${CMAKE_SOURCE_DIR}/../nitrogen/generated/android/RNVoicevox+autolinking.cmake)
