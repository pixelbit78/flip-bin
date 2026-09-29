import 'package:shared_preferences/shared_preferences.dart';

/// Persists that the user has successfully granted camera access once.
///
/// Real permission state lives in the browser (Permissions API / Chrome site
/// settings). This flag is a UX hint so we skip the one-shot "Allow camera"
/// overlay on reopen when the browser already remembers grant.
class CameraPermissionStore {
  static const _kAllowed = 'flipbin.camera.allowed';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> isAllowed() async {
    final prefs = await _prefs;
    return prefs.getBool(_kAllowed) ?? false;
  }

  Future<void> setAllowed(bool allowed) async {
    final prefs = await _prefs;
    await prefs.setBool(_kAllowed, allowed);
  }
}
