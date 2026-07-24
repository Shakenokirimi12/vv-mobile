import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'errors.dart';
import 'license_gate.dart';
import 'model_info.dart';

/// .vvm モデルファイルの実行時ダウンロードとローカルキャッシュ管理。
class ModelManager {
  ModelManager({
    required LicenseCatalog catalog,
    required LicenseGate gate,
    required Directory modelsDir,
  })  : _catalog = catalog,
        _gate = gate,
        _modelsDir = modelsDir {
    _modelsDir.createSync(recursive: true);
  }

  final LicenseCatalog _catalog;
  final LicenseGate _gate;
  final Directory _modelsDir;

  VoicevoxModelInfo info(String modelId) =>
      _catalog.models.firstWhere(
        (m) => m.id == modelId,
        orElse: () => throw UnknownModelException(modelId),
      );

  /// モデルのローカルパス。
  File localFile(String modelId) =>
      File(p.join(_modelsDir.path, info(modelId).filename));

  /// ダウンロード済みか。
  bool isDownloaded(String modelId) => localFile(modelId).existsSync();

  /// 1モデルをダウンロードする(要同意)。ダウンロード済みなら何もしない。
  Future<void> download(String modelId, {http.Client? client}) async {
    _gate.require(modelId);
    final model = info(modelId);
    final dest = localFile(modelId);
    if (dest.existsSync()) return;

    final ownedClient = client ?? http.Client();
    try {
      final request = http.Request('GET', Uri.parse(model.downloadURL));
      final response = await ownedClient.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DownloadFailedException(modelId, 'HTTP ${response.statusCode}');
      }
      final tmp = File('${dest.path}.part-${DateTime.now().microsecondsSinceEpoch}');
      final sink = tmp.openWrite();
      try {
        await response.stream.pipe(sink);
      } finally {
        await sink.close();
      }
      // 別Futureが先に完了していた場合は置き換えない
      if (!dest.existsSync()) {
        tmp.renameSync(dest.path);
      } else {
        tmp.deleteSync();
      }
    } on VoicevoxException {
      rethrow;
    } catch (e) {
      throw DownloadFailedException(modelId, e.toString());
    } finally {
      if (client == null) ownedClient.close();
    }
  }

  /// ダウンロード済みモデルを削除する。
  void remove(String modelId) {
    final file = localFile(modelId);
    if (file.existsSync()) file.deleteSync();
  }
}
