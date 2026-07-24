/// 音声モデル(.vvm)1件のメタデータ。licenses.json 由来。
class VoicevoxModelInfo {
  const VoicevoxModelInfo({
    required this.id,
    required this.filename,
    required this.sizeBytes,
    required this.downloadURL,
    required this.vvmId,
    required this.characters,
    this.isDownloaded = false,
  });

  factory VoicevoxModelInfo.fromJson(Map<String, dynamic> json) =>
      VoicevoxModelInfo(
        id: json['id'] as String,
        filename: json['filename'] as String,
        sizeBytes: json['sizeBytes'] as int,
        downloadURL: json['downloadURL'] as String,
        vvmId: json['vvmId'] as String,
        characters: (json['characters'] as List)
            .map((c) =>
                VoicevoxCharacter.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String filename;
  final int sizeBytes;
  final String downloadURL;
  final String vvmId;
  final List<VoicevoxCharacter> characters;

  /// listModels() 時に付与されるダウンロード状態。
  final bool isDownloaded;

  VoicevoxModelInfo withDownloaded(bool downloaded) => VoicevoxModelInfo(
        id: id,
        filename: filename,
        sizeBytes: sizeBytes,
        downloadURL: downloadURL,
        vvmId: vvmId,
        characters: characters,
        isDownloaded: downloaded,
      );
}

class VoicevoxCharacter {
  const VoicevoxCharacter({
    required this.name,
    required this.speakerUuid,
    required this.creditText,
    required this.termsURL,
    required this.styles,
  });

  factory VoicevoxCharacter.fromJson(Map<String, dynamic> json) =>
      VoicevoxCharacter(
        name: json['name'] as String,
        speakerUuid: json['speakerUuid'] as String,
        creditText: json['creditText'] as String,
        termsURL: json['termsURL'] as String,
        styles: (json['styles'] as List)
            .map((s) => VoicevoxStyle.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  final String name;
  final String speakerUuid;

  /// 生成音声の利用時に必要なクレジット表記(例: "VOICEVOX:ずんだもん")。
  final String creditText;

  /// キャラクター個別の利用規約URL。
  final String termsURL;
  final List<VoicevoxStyle> styles;
}

class VoicevoxStyle {
  const VoicevoxStyle({required this.name, required this.id});

  factory VoicevoxStyle.fromJson(Map<String, dynamic> json) =>
      VoicevoxStyle(name: json['name'] as String, id: json['id'] as int);

  final String name;
  final int id;
}

/// licenses.json 全体。
class LicenseCatalog {
  const LicenseCatalog({
    required this.termsVersion,
    required this.termsURL,
    required this.models,
  });

  factory LicenseCatalog.fromJson(Map<String, dynamic> json) => LicenseCatalog(
        termsVersion: json['termsVersion'] as String,
        termsURL: json['termsURL'] as String,
        models: (json['models'] as List)
            .map((m) =>
                VoicevoxModelInfo.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  final String termsVersion;
  final String termsURL;
  final List<VoicevoxModelInfo> models;
}
