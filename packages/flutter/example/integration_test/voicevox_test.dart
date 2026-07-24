import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voicevox_flutter/voicevox_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Voicevox voicevox;

  setUpAll(() async {
    voicevox = await Voicevox.create();
  });

  tearDownAll(() {
    voicevox.dispose();
  });

  testWidgets('listModels returns all models with characters',
      (tester) async {
    final models = voicevox.listModels();
    expect(models, isNotEmpty);
    for (final model in models) {
      expect(model.characters, isNotEmpty, reason: 'model ${model.id}');
      expect(model.downloadURL, startsWith('https://'));
    }
  });

  testWidgets('synthesis without download throws ModelNotDownloadedException',
      (tester) async {
    expect(
      () => voicevox.synthesis('テスト', modelId: '0'),
      throwsA(isA<ModelNotDownloadedException>()),
    );
  });

  testWidgets('download without license throws LicenseNotAcceptedException',
      (tester) async {
    await voicevox.gate.revoke('1');
    expect(
      () => voicevox.downloadModel('1'),
      throwsA(isA<LicenseNotAcceptedException>()),
    );
  });

  testWidgets('end-to-end: accept, download, synthesize, RIFF header',
      (tester) async {
    await voicevox.acceptLicense('0');
    await voicevox.downloadModel('0');
    expect(voicevox.listModels().firstWhere((m) => m.id == '0').isDownloaded,
        isTrue);

    // ずんだもん(スタイル3=ノーマル)
    final wav =
        await voicevox.synthesis('こんにちは、ずんだもんなのだ', modelId: '0', styleId: 3);
    expect(wav.length, greaterThan(44));
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
  });

  testWidgets('parallel download with partial failure', (tester) async {
    await voicevox.acceptLicense('2');
    await voicevox.gate.revoke('3');

    final results = await voicevox.downloadModels(['2', '3']);
    expect(results['2'], isNull);
    expect(results['3'], isA<LicenseNotAcceptedException>());
  });
}
