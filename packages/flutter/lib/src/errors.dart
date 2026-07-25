/// vv-mobile パッケージ固有の失敗。
sealed class VoicevoxException implements Exception {
  const VoicevoxException(this.message);

  final String message;

  @override
  String toString() => 'VoicevoxException: $message';
}

/// voicevox_core の C API がエラーコードを返した。
class VoicevoxCoreException extends VoicevoxException {
  const VoicevoxCoreException(this.code, String message) : super(message);

  final int code;

  @override
  String toString() => 'VoicevoxCoreException($code): $message';
}

/// モデルの利用規約に未同意のまま取得・ロードしようとした。
class LicenseNotAcceptedException extends VoicevoxException {
  const LicenseNotAcceptedException(this.modelId)
      : super('モデル $modelId の利用規約に同意していません。'
            'LicenseGate.accept で同意してください');

  final String modelId;
}

/// 未ダウンロードのモデルで合成しようとした。
class ModelNotDownloadedException extends VoicevoxException {
  const ModelNotDownloadedException(this.modelId)
      : super('モデル $modelId は未ダウンロードです。downloadModel を先に呼んでください');

  final String modelId;
}

/// licenses.json に存在しないモデルID。
class UnknownModelException extends VoicevoxException {
  const UnknownModelException(this.modelId) : super('不明なモデルID: $modelId');

  final String modelId;
}

/// Open JTalk 辞書のダウンロード・展開に失敗した。
class DictionaryDownloadException extends VoicevoxException {
  const DictionaryDownloadException(String cause)
      : super('Open JTalk 辞書の準備に失敗しました: $cause');
}

/// テキスト読み上げ(talk)非対応モデル(歌唱合成用 s0 など)で synthesis しようとした。
class TalkNotSupportedException extends VoicevoxException {
  const TalkNotSupportedException(this.modelId)
      : super('モデル $modelId はテキスト読み上げ(talk)に対応していません(歌唱合成用モデルです)');

  final String modelId;
}

/// ダウンロード失敗。
class DownloadFailedException extends VoicevoxException {
  const DownloadFailedException(this.modelId, String cause)
      : super('モデル $modelId のダウンロードに失敗しました: $cause');

  final String modelId;
}
