import 'package:shared_preferences/shared_preferences.dart';

import 'errors.dart';

/// モデル利用規約への同意状態を管理するゲート。
///
/// モデルのダウンロード・ロードは、対象モデルに対して [accept] 済みでない限り
/// [LicenseNotAcceptedException] で拒否される。
/// 同意状態は (modelId, termsVersion) の組で永続化されるため、
/// 利用規約のバージョンが上がると再同意が必要になる。
class LicenseGate {
  LicenseGate(this._prefs, this._termsVersion);

  static const _key = 'jp.voicevox.vv-mobile.acceptedLicenses';

  final SharedPreferences _prefs;
  final String _termsVersion;

  String _storageValue(String modelId) => '$modelId@$_termsVersion';

  Set<String> get _accepted => (_prefs.getStringList(_key) ?? []).toSet();

  /// モデルの利用規約に同意する。
  /// アプリ側は必ず利用者に規約(termsURL)を提示した上で呼ぶこと。
  Future<void> accept(String modelId) async {
    final set = _accepted..add(_storageValue(modelId));
    await _prefs.setStringList(_key, set.toList()..sort());
  }

  /// 同意を取り消す。
  Future<void> revoke(String modelId) async {
    final set = _accepted..remove(_storageValue(modelId));
    await _prefs.setStringList(_key, set.toList()..sort());
  }

  /// 現在の規約バージョンで同意済みか。
  bool isAccepted(String modelId) => _accepted.contains(_storageValue(modelId));

  /// 未同意なら [LicenseNotAcceptedException] を投げる。
  void require(String modelId) {
    if (!isAccepted(modelId)) {
      throw LicenseNotAcceptedException(modelId);
    }
  }
}
