import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'errors.dart';

/// Open JTalk 辞書(約100MB)の実行時ダウンロードと配置。
///
/// pub.dev の配布物にはサイズの都合で辞書を含めないため、`.vvm` 音声モデルと
/// 同じく初回利用時にダウンロードする(辞書はキャラクター非依存で
/// ライセンス同意は不要)。展開済みならスキップする冪等な処理。
class DictionaryManager {
  /// [url] と [sha256Hash] はテストで小さなアーカイブに差し替えるための口で、
  /// 通常は省略して [defaultUrl] / [defaultSha256] を使う。
  DictionaryManager({
    required Directory baseDir,
    http.Client? client,
    String? url,
    String? sha256Hash,
  })  : _baseDir = baseDir,
        _client = client,
        _url = url ?? defaultUrl,
        _sha256 = sha256Hash ?? defaultSha256;

  /// packages/core-native/VERSION と同期させること。
  static const version = '1.11';
  static const defaultUrl =
      'https://downloads.sourceforge.net/open-jtalk/open_jtalk_dic_utf_8-$version.tar.gz';

  /// packages/core-native/checksums.txt と同期させること。
  static const defaultSha256 =
      '33e9cd251bc41aa2bd7ca36f57abbf61eae3543ca25ca892ae345e394cb10549';

  final Directory _baseDir;
  final http.Client? _client;
  final String _url;
  final String _sha256;

  /// 進行中の [ensure] があればその Future。同時呼び出しで 100MB の
  /// ダウンロード・展開が二重に走らないようにする。
  Future<Directory>? _pending;

  /// 辞書の配置先。
  Directory get directory =>
      Directory(p.join(_baseDir.path, 'voicevox/open_jtalk_dic'));

  /// 展開済みかどうか(`sys.dic` の存在で判定)。
  bool get isReady => File(p.join(directory.path, 'sys.dic')).existsSync();

  /// 辞書を用意する。既にあれば何もしない。
  ///
  /// [onProgress] は 0.0〜1.0(Content-Length 不明時は null)で進捗を通知する。
  /// 既に別の [ensure] が進行中の場合はそれに相乗りするため、後から渡した
  /// [onProgress] は無視される。
  Future<Directory> ensure({void Function(double? progress)? onProgress}) {
    if (isReady) return Future.value(directory);
    return _pending ??= _download(onProgress: onProgress).whenComplete(() {
      _pending = null;
    });
  }

  Future<Directory> _download(
      {void Function(double? progress)? onProgress}) async {
    final client = _client ?? http.Client();
    final tmpDir = await Directory.systemTemp.createTemp('voicevox-dict-');
    final archive = File(p.join(tmpDir.path, 'dict.tar.gz'));
    try {
      final response = await client.send(http.Request('GET', Uri.parse(_url)));
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

      // sourceforge は任意のミラーへリダイレクトするため、公式配布物と同一で
      // あることを必ず確認する(packages/core-native/checksums.txt と同じ値)。
      final actual = (await sha256.bind(archive.openRead()).first).toString();
      if (actual != _sha256) {
        throw DictionaryDownloadException(
            'checksum mismatch (expected $_sha256, got $actual)');
      }

      final extractTo = Directory(p.join(tmpDir.path, 'extracted'))
        ..createSync(recursive: true);
      // 一括展開すると gz 全体(約100MB)と sys.dic(約103MB)が同時に
      // メモリへ載り、モバイルでは OOM する。extractFileToDisk は
      // InputFileStream / OutputFileStream でストリーム展開し、出力先の外へ
      // 出るエントリ(絶対パスや `..`)を弾く。UI をブロックしないよう
      // 別 isolate で実行する。
      final archivePath = archive.path;
      final extractPath = extractTo.path;
      await Isolate.run(() => extractFileToDisk(archivePath, extractPath));

      // アーカイブ内のパスは open_jtalk_dic_utf_8-<version>/<file>
      final extracted =
          Directory(p.join(extractTo.path, 'open_jtalk_dic_utf_8-$version'));
      if (!File(p.join(extracted.path, 'sys.dic')).existsSync()) {
        throw const DictionaryDownloadException(
            'unexpected archive layout (open_jtalk_dic_utf_8-$version/sys.dic '
            'not found)');
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
