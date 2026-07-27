import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:voicevox_flutter/voicevox_flutter.dart';

/// テスト用の小さな tar.gz を組み立てる。実物と同じく
/// `open_jtalk_dic_utf_8-<version>/<file>` という構造。
Uint8List _buildDictArchive({
  String dirName = 'open_jtalk_dic_utf_8-${DictionaryManager.version}',
  List<String> extraEntries = const [],
}) {
  final archive = Archive()
    ..add(ArchiveFile.string('$dirName/sys.dic', 'sys'))
    ..add(ArchiveFile.string('$dirName/char.bin', 'char'));
  for (final name in extraEntries) {
    archive.add(ArchiveFile.string(name, 'evil'));
  }
  return GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive));
}

/// `send` を差し替えられる最小の Client。呼ばれた回数を数える。
class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.StreamedResponse> Function() _handler;
  int sendCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sendCount++;
    return _handler();
  }
}

/// [body] を [chunkSize] ずつ流す 200 レスポンス。
http.StreamedResponse _ok(
  List<int> body, {
  bool withContentLength = true,
  int chunkSize = 16,
}) {
  final chunks = <List<int>>[];
  for (var i = 0; i < body.length; i += chunkSize) {
    chunks.add(body.sublist(i, (i + chunkSize).clamp(0, body.length)));
  }
  return http.StreamedResponse(
    Stream.fromIterable(chunks),
    200,
    contentLength: withContentLength ? body.length : null,
  );
}

String _sha256(List<int> bytes) => sha256.convert(bytes).toString();

void main() {
  late Directory baseDir;

  setUp(() {
    baseDir = Directory.systemTemp.createTempSync('voicevox-dict-test-');
  });

  tearDown(() {
    if (baseDir.existsSync()) baseDir.deleteSync(recursive: true);
  });

  DictionaryManager managerFor(_FakeClient client, List<int> body) =>
      DictionaryManager(
        baseDir: baseDir,
        client: client,
        url: 'https://example.invalid/dict.tar.gz',
        sha256Hash: _sha256(body),
      );

  test('展開済みならダウンロードしない', () async {
    final dictDir = Directory(p.join(baseDir.path, 'voicevox/open_jtalk_dic'))
      ..createSync(recursive: true);
    File(p.join(dictDir.path, 'sys.dic')).writeAsStringSync('already here');

    final client = _FakeClient(() async => _ok(const []));
    final manager = managerFor(client, const []);

    expect(manager.isReady, isTrue);
    expect((await manager.ensure()).path, dictDir.path);
    expect(client.sendCount, 0);
    // 既存の辞書を消していない
    expect(File(p.join(dictDir.path, 'sys.dic')).readAsStringSync(),
        'already here');
  });

  test('ダウンロードして展開する', () async {
    final body = _buildDictArchive();
    final client = _FakeClient(() async => _ok(body));
    final manager = managerFor(client, body);

    final dir = await manager.ensure();

    expect(client.sendCount, 1);
    expect(manager.isReady, isTrue);
    expect(dir.path, p.join(baseDir.path, 'voicevox/open_jtalk_dic'));
    expect(File(p.join(dir.path, 'sys.dic')).readAsStringSync(), 'sys');
    expect(File(p.join(dir.path, 'char.bin')).existsSync(), isTrue);
  });

  test('非 2xx は DictionaryDownloadException', () async {
    final client = _FakeClient(
        () async => http.StreamedResponse(const Stream.empty(), 503));
    final manager = managerFor(client, const []);

    await expectLater(
      manager.ensure(),
      throwsA(isA<DictionaryDownloadException>()
          .having((e) => e.message, 'message', contains('HTTP 503'))),
    );
    expect(manager.isReady, isFalse);
  });

  test('チェックサム不一致は展開せずに失敗する', () async {
    final body = _buildDictArchive();
    final client = _FakeClient(() async => _ok(body));
    final manager = DictionaryManager(
      baseDir: baseDir,
      client: client,
      url: 'https://example.invalid/dict.tar.gz',
      sha256Hash: _sha256(utf8.encode('something else')),
    );

    await expectLater(
      manager.ensure(),
      throwsA(isA<DictionaryDownloadException>()
          .having((e) => e.message, 'message', contains('checksum mismatch'))),
    );
    expect(manager.isReady, isFalse);
  });

  test('想定外のアーカイブ構造は検出する', () async {
    final body = _buildDictArchive(dirName: 'some_other_dir');
    final client = _FakeClient(() async => _ok(body));
    final manager = managerFor(client, body);

    await expectLater(
      manager.ensure(),
      throwsA(isA<DictionaryDownloadException>().having(
          (e) => e.message, 'message', contains('unexpected archive layout'))),
    );
    expect(manager.isReady, isFalse);
  });

  test('展開先の外へ出るエントリは書き出さない', () async {
    // 絶対パスのエントリ。p.join は第2引数が絶対パスだとそのまま返すので、
    // 素朴に join すると展開先の外へ書けてしまう。
    final escapee = File(p.join(baseDir.path, 'escape', 'pwned.txt'));
    escapee.parent.createSync(recursive: true);
    final body = _buildDictArchive(
        extraEntries: [escapee.path, '../../../etc/pwned.txt']);
    final client = _FakeClient(() async => _ok(body));
    final manager = managerFor(client, body);

    await manager.ensure();

    // 辞書自体は展開され、外へ出るエントリだけが落ちる
    expect(manager.isReady, isTrue);
    expect(escapee.existsSync(), isFalse);
  });

  test('Content-Length があれば 0.0〜1.0 の進捗を通知する', () async {
    final body = _buildDictArchive();
    final client = _FakeClient(() async => _ok(body));
    final manager = managerFor(client, body);

    final progress = <double?>[];
    await manager.ensure(onProgress: progress.add);

    expect(progress, isNotEmpty);
    expect(progress.every((v) => v != null && v > 0 && v <= 1.0), isTrue);
    expect(progress.last, 1.0);
  });

  test('Content-Length 不明なら null を通知する', () async {
    final body = _buildDictArchive();
    final client = _FakeClient(() async => _ok(body, withContentLength: false));
    final manager = managerFor(client, body);

    final progress = <double?>[];
    await manager.ensure(onProgress: progress.add);

    expect(progress, isNotEmpty);
    expect(progress.every((v) => v == null), isTrue);
  });

  test('同時に呼んでもダウンロードは 1 回だけ', () async {
    final body = _buildDictArchive();
    final client = _FakeClient(() async => _ok(body));
    final manager = managerFor(client, body);

    final results = await Future.wait([manager.ensure(), manager.ensure()]);

    expect(client.sendCount, 1);
    expect(results[0].path, results[1].path);
    expect(manager.isReady, isTrue);
  });

  test('失敗後に再試行できる', () async {
    final body = _buildDictArchive();
    var attempt = 0;
    final client = _FakeClient(() async {
      attempt++;
      if (attempt == 1) {
        return http.StreamedResponse(const Stream.empty(), 500);
      }
      return _ok(body);
    });
    final manager = managerFor(client, body);

    await expectLater(
        manager.ensure(), throwsA(isA<DictionaryDownloadException>()));
    await manager.ensure();

    expect(client.sendCount, 2);
    expect(manager.isReady, isTrue);
  });
}
