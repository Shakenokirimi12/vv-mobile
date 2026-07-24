import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.g.dart';
import 'errors.dart';

/// voicevox_core C API の薄いラッパー。
/// ONNX Runtime / Open JTalk / Synthesizer のライフサイクルを1つに束ねる。
class Synthesizer {
  Synthesizer._(this._bindings, this._synthesizer, this._openJtalk);

  final VoicevoxBindings _bindings;
  final Pointer<VoicevoxSynthesizer> _synthesizer;
  final Pointer<OpenJtalkRc> _openJtalk;
  final Set<String> _loadedModelIds = {};
  bool _disposed = false;

  static DynamicLibrary _openLibrary() {
    if (Platform.isIOS) {
      // vendored xcframework はアプリにリンク済み
      return DynamicLibrary.process();
    }
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libvoicevox_core.so');
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('libvoicevox_core.dylib');
    }
    if (Platform.isLinux) {
      return DynamicLibrary.open('libvoicevox_core.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('voicevox_core.dll');
    }
    throw UnsupportedError('unsupported platform: ${Platform.operatingSystem}');
  }

  static void _check(VoicevoxBindings bindings, int code) {
    if (code != 0) {
      final message =
          bindings.voicevox_error_result_to_message(code).cast<Utf8>().toDartString();
      throw VoicevoxCoreException(code, message);
    }
  }

  /// 初期化する。
  ///
  /// [openJtalkDictDir] Open JTalk 辞書ディレクトリ(必須)。
  /// [onnxruntimePath] macOS/Linux/Windows での ONNX Runtime 動的ライブラリの
  /// パス。null ならデフォルトのファイル名で探索する。iOS/Android では不要。
  factory Synthesizer({
    required String openJtalkDictDir,
    String? onnxruntimePath,
  }) {
    final bindings = VoicevoxBindings(_openLibrary());

    // ONNX Runtime のロード。
    // iOS はリンク時動的リンク(init_once)、他は実行時ロード(load_once)。
    // 生成バインディングは load_once 側なので、iOS のみ手動 lookup する。
    final onnxruntimeOut =
        calloc<Pointer<VoicevoxOnnxruntime>>();
    try {
      if (Platform.isIOS) {
        final initOnce = _openLibrary().lookupFunction<
            Int32 Function(Pointer<Pointer<VoicevoxOnnxruntime>>),
            int Function(
                Pointer<Pointer<VoicevoxOnnxruntime>>)>('voicevox_onnxruntime_init_once');
        _check(bindings, initOnce(onnxruntimeOut));
      } else {
        var options = bindings.voicevox_make_default_load_onnxruntime_options();
        Pointer<Utf8>? filenamePtr;
        if (onnxruntimePath != null) {
          filenamePtr = onnxruntimePath.toNativeUtf8();
          options.filename = filenamePtr.cast();
        }
        try {
          _check(
            bindings,
            bindings.voicevox_onnxruntime_load_once(options, onnxruntimeOut),
          );
        } finally {
          if (filenamePtr != null) calloc.free(filenamePtr);
        }
      }
      final onnxruntime = onnxruntimeOut.value;

      // Open JTalk 辞書
      final openJtalkOut = calloc<Pointer<OpenJtalkRc>>();
      final dictPtr = openJtalkDictDir.toNativeUtf8();
      try {
        _check(
          bindings,
          bindings.voicevox_open_jtalk_rc_new(dictPtr.cast(), openJtalkOut),
        );
        final openJtalk = openJtalkOut.value;

        // Synthesizer
        final synthOut = calloc<Pointer<VoicevoxSynthesizer>>();
        try {
          final options = bindings.voicevox_make_default_initialize_options();
          final code = bindings.voicevox_synthesizer_new(
              onnxruntime, openJtalk, options, synthOut);
          if (code != 0) {
            bindings.voicevox_open_jtalk_rc_delete(openJtalk);
            _check(bindings, code);
          }
          return Synthesizer._(bindings, synthOut.value, openJtalk);
        } finally {
          calloc.free(synthOut);
        }
      } finally {
        calloc.free(dictPtr);
        calloc.free(openJtalkOut);
      }
    } finally {
      calloc.free(onnxruntimeOut);
    }
  }

  /// .vvm ファイルをロードする。同一モデルの二重ロードは無視される。
  void loadVoiceModel(String path, {required String modelId}) {
    _ensureAlive();
    if (_loadedModelIds.contains(modelId)) return;

    final modelOut = calloc<Pointer<VoicevoxVoiceModelFile>>();
    final pathPtr = path.toNativeUtf8();
    try {
      _check(
        _bindings,
        _bindings.voicevox_voice_model_file_open(pathPtr.cast(), modelOut),
      );
      final model = modelOut.value;
      try {
        _check(
          _bindings,
          _bindings.voicevox_synthesizer_load_voice_model(_synthesizer, model),
        );
        _loadedModelIds.add(modelId);
      } finally {
        _bindings.voicevox_voice_model_file_delete(model);
      }
    } finally {
      calloc.free(pathPtr);
      calloc.free(modelOut);
    }
  }

  /// モデルがロード済みかどうか。
  bool isLoaded(String modelId) => _loadedModelIds.contains(modelId);

  /// テキストから WAV を合成する。
  Uint8List tts(String text, {required int styleId}) {
    _ensureAlive();
    final textPtr = text.toNativeUtf8();
    final lengthOut = calloc<UintPtr>();
    final wavOut = calloc<Pointer<Uint8>>();
    try {
      final options = _bindings.voicevox_make_default_tts_options();
      _check(
        _bindings,
        _bindings.voicevox_synthesizer_tts(
            _synthesizer, textPtr.cast(), styleId, options, lengthOut, wavOut),
      );
      final wav = wavOut.value;
      final length = lengthOut.value;
      try {
        // ネイティブ側バッファからDart側へコピー
        return Uint8List.fromList(wav.asTypedList(length));
      } finally {
        _bindings.voicevox_wav_free(wav);
      }
    } finally {
      calloc.free(textPtr);
      calloc.free(lengthOut);
      calloc.free(wavOut);
    }
  }

  /// voicevox_core のバージョン文字列。
  String get coreVersion =>
      _bindings.voicevox_get_version().cast<Utf8>().toDartString();

  void _ensureAlive() {
    if (_disposed) {
      throw StateError('Synthesizer is already disposed');
    }
  }

  /// ネイティブリソースを解放する。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bindings.voicevox_synthesizer_delete(_synthesizer);
    _bindings.voicevox_open_jtalk_rc_delete(_openJtalk);
  }
}
