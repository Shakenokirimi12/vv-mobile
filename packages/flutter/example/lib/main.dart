import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voicevox_flutter/voicevox_flutter.dart';

void main() {
  runApp(const MaterialApp(home: HomePage()));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Voicevox? _voicevox;
  List<VoicevoxModelInfo> _models = [];
  final _textController =
      TextEditingController(text: 'こんにちは、ずんだもんなのだ');
  final _player = AudioPlayer();
  String _status = '初期化中...';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final voicevox = await Voicevox.create(
        // 初回は Open JTalk 辞書(約100MB)をダウンロードする
        onDictionaryProgress: (progress) {
          if (!mounted) return;
          setState(() => _status = progress == null
              ? '辞書をダウンロード中...'
              : '辞書をダウンロード中... ${(progress * 100).toStringAsFixed(0)}%');
        },
      );
      setState(() {
        _voicevox = voicevox;
        _models = voicevox.listModels();
        _status = '準備完了';
      });
    } catch (e) {
      setState(() => _status = '初期化失敗: $e');
    }
  }

  Future<void> _download(VoicevoxModelInfo model) async {
    final voicevox = _voicevox!;
    if (!voicevox.isLicenseAccepted(model.id)) {
      final accepted = await _showLicenseDialog(model);
      if (!accepted) return;
      await voicevox.acceptLicense(model.id);
    }
    setState(() {
      _busy = true;
      _status = '${model.id} をダウンロード中...';
    });
    try {
      await voicevox.downloadModel(model.id);
      setState(() {
        _models = voicevox.listModels();
        _status = '${model.id} ダウンロード完了';
      });
    } on VoicevoxException catch (e) {
      setState(() => _status = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<bool> _showLicenseDialog(VoicevoxModelInfo model) async {
    final characters = model.characters.map((c) => c.name).join('、');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('利用規約への同意'),
        content: Text(
          'このモデルには $characters が含まれます。\n\n'
          '利用には VOICEVOX 音声モデル利用規約および各キャラクターの利用規約への'
          '同意が必要です。生成音声の利用時はクレジット表記'
          '(例: ${model.characters.first.creditText})が必要です。\n\n'
          '規約: ${_voicevox!.termsURL}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('同意しない'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('同意する'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// キャラクター×スタイル(talkのみ)を選ばせてから合成する。
  Future<void> _selectStyleAndSpeak(VoicevoxModelInfo model) async {
    final styles = [
      for (final character in model.characters)
        for (final style in character.talkStyles)
          (label: '${character.name}(${style.name})', id: style.id),
    ];
    if (styles.isEmpty) {
      setState(() => _status = 'このモデルは歌唱合成用のため読み上げには使えません');
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => ListView(
        children: [
          const ListTile(title: Text('キャラクター・スタイルを選択')),
          for (final style in styles)
            ListTile(
              title: Text(style.label),
              onTap: () => Navigator.pop(context, style.id),
            ),
        ],
      ),
    );
    if (selected != null) {
      await _speak(model, styleId: selected);
    }
  }

  Future<void> _speak(VoicevoxModelInfo model, {int? styleId}) async {
    setState(() {
      _busy = true;
      _status = '合成中...';
    });
    try {
      final wav = await _voicevox!
          .synthesis(_textController.text, modelId: model.id, styleId: styleId);
      // BytesSource は iOS でハングすることがあるため、一時ファイル経由で再生する
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/voicevox_out.wav');
      await file.writeAsBytes(wav, flush: true);
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      setState(
          () => _status = '再生中 (styleId=${styleId ?? "auto"}, ${wav.length} bytes)');
    } on VoicevoxException catch (e) {
      setState(() => _status = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('voicevox_flutter example')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: '読み上げテキスト',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Text(_status),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _models.length,
              itemBuilder: (context, index) {
                final model = _models[index];
                final characters =
                    model.characters.map((c) => c.name).join('、');
                return ListTile(
                  title: Text('モデル ${model.id}'),
                  subtitle: Text(
                    characters,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: model.isDownloaded
                      ? IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed:
                              _busy ? null : () => _selectStyleAndSpeak(model),
                        )
                      : IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: _busy ? null : () => _download(model),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _player.dispose();
    _voicevox?.dispose();
    super.dispose();
  }
}
