import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'errors.dart';

/// Open JTalk 辞書(約100MB)の実行時ダウンロードと配置。
///
/// pub.dev の配布物にはサイズの都合で辞書を含めないため、`.vvm` 音声モデルと
/// 同じく初回利用時にダウンロードする(辞書はキャラクター非依存で
/// ライセンス同意は不要)。展開済みならスキップする冪等な処理。
class DictionaryManager {
  DictionaryManager({required Directory baseDir, http.Client? client})
      : _baseDir = baseDir,
        _client = client;

  /// packages/core-native/VERSION と同期させること。
  static const version = '1.11';
  static const _url =
      'https://downloads.sourceforge.net/open-jtalk/open_jtalk_dic_utf_8-$version.tar.gz';

  final Directory _baseDir;
  final http.Client? _client;

  /// 辞書の配置先。
  Directory get directory =>
      Directory(p.join(_baseDir.path, 'voicevox/open_jtalk_dic'));

  /// 展開済みかどうか(`sys.dic` の存在で判定)。
  bool get isReady => File(p.join(directory.path, 'sys.dic')).existsSync();

  /// 辞書を用意する。既にあれば何もしない。
  ///
  /// [onProgress] は 0.0〜1.0(Content-Length 不明時は null)で進捗を通知する。
  Future<Directory> ensure({void Function(double? progress)? onProgress}) async {
    if (isReady) return directory;

    final client = _client ?? http.Client();
    final tmpDir = await Directory.systemTemp.createTemp('voicevox-dict-');
    final archive = File(p.join(tmpDir.path, 'dict.tar.gz'));
    try {
      final response =
          await client.send(http.Request('GET', Uri.parse(_url)));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DictionaryDownloadException('HTTP ${response.statusCode}');
      }

      final total = response.contentLength;
      var received = 0;
      final sink = archive.openWrite();
      try {
        await response.stream.map((chunk) {
          received += chunk.length;
          onProgress?.call(total == null ? null : received / total);
          return chunk;
        }).pipe(sink);
      } finally {
        await sink.close();
      }

      // iOS ではプロセス起動が禁止されているため、純 Dart で展開する。
      final extractTo = Directory(p.join(tmpDir.path, 'extracted'))
        ..createSync(recursive: true);
      final tarBytes = GZipDecoder().decodeBytes(await archive.readAsBytes());
      final entries = TarDecoder().decodeBytes(tarBytes);
      for (final entry in entries) {
        if (!entry.isFile) continue;
        // アーカイブ内のパスは open_jtalk_dic_utf_8-<version>/<file>
        final out = File(p.join(extractTo.path, entry.name));
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(entry.content as List<int>);
      }

      final extracted =
          Directory(p.join(extractTo.path, 'open_jtalk_dic_utf_8-$version'));
      if (!extracted.existsSync()) {
        throw const DictionaryDownloadException(
            'unexpected archive layout (open_jtalk_dic_utf_8-$version not found)');
      }

      // 別 isolate が先に完了していた場合は置き換えない
      if (!isReady) {
        directory.parent.createSync(recursive: true);
        if (directory.existsSync()) directory.deleteSync(recursive: true);
        extracted.renameSync(directory.path);
      }
      return directory;
    } on VoicevoxException {
      rethrow;
    } catch (e) {
      throw DictionaryDownloadException(e.toString());
    } finally {
      if (_client == null) client.close();
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    }
  }
}
