/// VOICEVOX CORE の Flutter バインディング。
///
/// ```dart
/// final voicevox = await Voicevox.create();
///
/// // 1. モデル一覧
/// final models = voicevox.listModels();
///
/// // 2. 利用規約に同意してダウンロード(個別 or 一括)
/// await voicevox.acceptLicense('0');
/// await voicevox.downloadModel('0');
///
/// // 3. 合成
/// final wav = await voicevox.synthesis('こんにちは', modelId: '0');
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pool/pool.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/errors.dart';
import 'src/license_gate.dart';
import 'src/model_info.dart';
import 'src/model_manager.dart';
import 'src/synthesizer.dart';

export 'src/errors.dart';
export 'src/license_gate.dart';
export 'src/model_info.dart';
export 'src/model_manager.dart';
export 'src/synthesizer.dart';

/// 高レベル Facade。通常の利用はこのクラスだけで完結する。
class Voicevox {
  Voicevox._({
    required LicenseCatalog catalog,
    required this.gate,
    required ModelManager manager,
    required Synthesizer synthesizer,
    required int maxConcurrentDownloads,
  })  : _catalog = catalog,
        _manager = manager,
        _synthesizer = synthesizer,
        _downloadPool = Pool(maxConcurrentDownloads);

  final LicenseCatalog _catalog;
  final ModelManager _manager;
  final Synthesizer _synthesizer;
  final Pool _downloadPool;

  /// ライセンス同意ゲート。
  final LicenseGate gate;

  static const _assetPrefix = 'packages/voicevox_flutter/assets';

  /// Facade を構築する。ネイティブ初期化と辞書展開を含む。
  ///
  /// [modelsDir] モデル保存先(null なら ApplicationSupport/voicevox/models)。
  /// [onnxruntimePath] デスクトップでの ONNX Runtime dylib パス。
  /// [maxConcurrentDownloads] 並列ダウンロードの同時実行数(既定4)。
  static Future<Voicevox> create({
    Directory? modelsDir,
    String? onnxruntimePath,
    int maxConcurrentDownloads = 4,
  }) async {
    final catalogJson =
        await rootBundle.loadString('$_assetPrefix/licenses.json');
    final catalog = LicenseCatalog.fromJson(
        jsonDecode(catalogJson) as Map<String, dynamic>);

    final prefs = await SharedPreferences.getInstance();
    final gate = LicenseGate(prefs, catalog.termsVersion);

    final support = await getApplicationSupportDirectory();
    final manager = ModelManager(
      catalog: catalog,
      gate: gate,
      modelsDir:
          modelsDir ?? Directory(p.join(support.path, 'voicevox/models')),
    );

    final dictDir = await _extractOpenJtalkDict(support);
    final synthesizer = Synthesizer(
      openJtalkDictDir: dictDir.path,
      onnxruntimePath: onnxruntimePath,
    );

    return Voicevox._(
      catalog: catalog,
      gate: gate,
      manager: manager,
      synthesizer: synthesizer,
      maxConcurrentDownloads:
          maxConcurrentDownloads < 1 ? 1 : maxConcurrentDownloads,
    );
  }

  /// アセットの Open JTalk 辞書をファイルシステムへ展開する(展開済みならスキップ)。
  static Future<Directory> _extractOpenJtalkDict(Directory support) async {
    final dictDir = Directory(p.join(support.path, 'voicevox/open_jtalk_dic'));
    final marker = File(p.join(dictDir.path, '.complete'));
    if (marker.existsSync()) return dictDir;

    dictDir.createSync(recursive: true);
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest
        .listAssets()
        .where((a) => a.startsWith('$_assetPrefix/open_jtalk_dic/'));
    for (final asset in assets) {
      final data = await rootBundle.load(asset);
      final file = File(p.join(dictDir.path, p.basename(asset)));
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    marker.createSync();
    return dictDir;
  }

  // --- モデル一覧 ---

  /// 利用可能な全モデルの一覧(ダウンロード状態付き)。
  List<VoicevoxModelInfo> listModels() => _catalog.models
      .map((m) => m.withDownloaded(_manager.isDownloaded(m.id)))
      .toList();

  /// 全モデル共通の利用規約(VOICEVOX 音声モデル利用規約)のURL。
  String get termsURL => _catalog.termsURL;

  // --- ライセンス同意 ---

  /// モデルの利用規約に同意する。アプリ側は規約を提示した上で呼ぶこと。
  Future<void> acceptLicense(String modelId) => gate.accept(modelId);

  /// 同意状態を確認する。
  bool isLicenseAccepted(String modelId) => gate.isAccepted(modelId);

  // --- ダウンロード ---

  /// 1モデルをダウンロードする(要同意)。ダウンロード済みなら何もしない。
  Future<void> downloadModel(String id) => _manager.download(id);

  /// 複数モデルを並列ダウンロードする(同時実行数は maxConcurrentDownloads)。
  ///
  /// 戻り値はモデルIDごとの成否(null=成功、例外=失敗)。一部失敗でも throw しない。
  Future<Map<String, VoicevoxException?>> downloadModels(
      List<String> ids) async {
    final results = await Future.wait(ids.map((id) async {
      return _downloadPool.withResource(() async {
        try {
          await _manager.download(id);
          return MapEntry<String, VoicevoxException?>(id, null);
        } on VoicevoxException catch (e) {
          return MapEntry<String, VoicevoxException?>(id, e);
        } catch (e) {
          return MapEntry<String, VoicevoxException?>(
              id, DownloadFailedException(id, e.toString()));
        }
      });
    }));
    return Map.fromEntries(results);
  }

  /// 全モデルを一括ダウンロードする(全モデルへの同意が必要)。
  Future<Map<String, VoicevoxException?>> downloadAllModels() =>
      downloadModels(_catalog.models.map((m) => m.id).toList());

  // --- 合成 ---

  /// テキストから音声(WAV)を合成する。
  ///
  /// モデルが未ダウンロードの場合は [ModelNotDownloadedException] を投げる
  /// (暗黙のダウンロードは行わない)。未ロードならロードしてから合成する。
  ///
  /// [styleId] は characters[].styles[] から選ぶ。null なら最初の talk スタイル。
  /// talk スタイルを持たないモデル(歌唱合成用の s0 など)は
  /// [TalkNotSupportedException] を投げる。
  Future<Uint8List> synthesis(
    String text, {
    required String modelId,
    int? styleId,
  }) async {
    final info = _manager.info(modelId);
    if (!info.supportsTalk) {
      throw TalkNotSupportedException(modelId);
    }
    if (!_manager.isDownloaded(modelId)) {
      throw ModelNotDownloadedException(modelId);
    }
    gate.require(modelId);

    if (!_synthesizer.isLoaded(modelId)) {
      _synthesizer.loadVoiceModel(
        _manager.localFile(modelId).path,
        modelId: modelId,
      );
    }

    final style = styleId ??
        info.characters
            .expand((c) => c.talkStyles)
            .map((s) => s.id)
            .firstOrNull;
    if (style == null) {
      throw TalkNotSupportedException(modelId);
    }
    return _synthesizer.tts(text, styleId: style);
  }

  /// ネイティブリソースを解放する。
  void dispose() => _synthesizer.dispose();
}
