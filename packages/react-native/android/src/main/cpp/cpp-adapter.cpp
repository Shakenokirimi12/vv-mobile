// JNI_OnLoad は nitrogen 生成の RNVoicevoxOnLoad.cpp が提供する。
// このファイルは CMake ターゲットの最小ソースとして存在する。
#include <jni.h>
#include "RNVoicevoxOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return margelo::nitro::voicevox::initialize(vm);
}
