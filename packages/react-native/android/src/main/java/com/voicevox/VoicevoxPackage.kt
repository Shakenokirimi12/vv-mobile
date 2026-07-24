package com.voicevox

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.margelo.nitro.voicevox.RNVoicevoxOnLoad

/**
 * RN autolinking から検出される ReactPackage。
 * Nitro Modules は TurboModule ではなく HybridObject 登録で動くため
 * モジュール自体は提供せず、ネイティブライブラリのロード
 * (RNVoicevoxOnLoad.initializeNative → System.loadLibrary)だけを担う。
 */
class VoicevoxPackage : BaseReactPackage() {
    override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? = null

    override fun getReactModuleInfoProvider(): ReactModuleInfoProvider =
        ReactModuleInfoProvider { HashMap() }

    companion object {
        init {
            RNVoicevoxOnLoad.initializeNative()
        }
    }
}
