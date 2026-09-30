import 'package:shared_preferences/shared_preferences.dart';

/// Persists Google session hints and spreadsheet ID across cold starts.
///
/// GIS access tokens are short-lived (~1h). We store the last access token so
/// a reload within that window can call Sheets/Drive without a fresh popup.
/// Identity restore still uses [GoogleSignIn.signInSilently].
class GoogleSessionStore {
  static const _kEmail = 'flipbin.google.email';
  static const _kDisplayName = 'flipbin.google.displayName';
  static const _kAccessToken = 'flipbin.google.accessToken';
  static const _kTokenExpiryMs = 'flipbin.google.tokenExpiryMs';
  static const _kSpreadsheetId = 'flipbin.google.spreadsheetId';
  static const _kLastSyncedMs = 'flipbin.google.lastSyncedMs';
  static const _kLastImportedMs = 'flipbin.google.lastImportedMs';
  static const _kAutoBackupEnabled = 'flipbin.autoBackup.enabled';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> saveSignedInUser({
    required String email,
    String? displayName,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_kEmail, email);
    if (displayName != null && displayName.isNotEmpty) {
      await prefs.setString(_kDisplayName, displayName);
    }
  }

  Future<void> saveAccessToken(String accessToken, {Duration ttl = const Duration(minutes: 55)}) async {
    final prefs = await _prefs;
    await prefs.setString(_kAccessToken, accessToken);
    await prefs.setInt(
      _kTokenExpiryMs,
      DateTime.now().add(ttl).millisecondsSinceEpoch,
    );
  }

  Future<void> saveSpreadsheetId(String? spreadsheetId) async {
    final prefs = await _prefs;
    if (spreadsheetId == null || spreadsheetId.isEmpty) {
      await prefs.remove(_kSpreadsheetId);
    } else {
      await prefs.setString(_kSpreadsheetId, spreadsheetId);
    }
  }

  Future<void> saveLastSyncedAt(DateTime? at) async {
    final prefs = await _prefs;
    if (at == null) {
      await prefs.remove(_kLastSyncedMs);
    } else {
      await prefs.setInt(_kLastSyncedMs, at.millisecondsSinceEpoch);
    }
  }

  Future<void> saveLastImportedAt(DateTime? at) async {
    final prefs = await _prefs;
    if (at == null) {
      await prefs.remove(_kLastImportedMs);
    } else {
      await prefs.setInt(_kLastImportedMs, at.millisecondsSinceEpoch);
    }
  }


  Future<bool> loadAutoBackupEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_kAutoBackupEnabled) ?? false;
  }

  Future<void> saveAutoBackupEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_kAutoBackupEnabled, enabled);
  }

  Future<GooglePersistedSession?> load() async {
    final prefs = await _prefs;
    final email = prefs.getString(_kEmail);
    if (email == null || email.isEmpty) return null;

    final token = prefs.getString(_kAccessToken);
    final expiryMs = prefs.getInt(_kTokenExpiryMs);
    final tokenValid = token != null &&
        token.isNotEmpty &&
        expiryMs != null &&
        DateTime.now().millisecondsSinceEpoch < expiryMs;

    final syncedMs = prefs.getInt(_kLastSyncedMs);
    final importedMs = prefs.getInt(_kLastImportedMs);

    return GooglePersistedSession(
      email: email,
      displayName: prefs.getString(_kDisplayName),
      accessToken: tokenValid ? token : null,
      spreadsheetId: prefs.getString(_kSpreadsheetId),
      lastSyncedAt: syncedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(syncedMs)
          : null,
      lastImportedAt: importedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(importedMs)
          : null,
    );
  }

  Future<void> clearAuth() async {
    final prefs = await _prefs;
    await prefs.remove(_kEmail);
    await prefs.remove(_kDisplayName);
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kTokenExpiryMs);
  }

  Future<void> clearAll() async {
    final prefs = await _prefs;
    await clearAuth();
    await prefs.remove(_kSpreadsheetId);
    await prefs.remove(_kLastSyncedMs);
    await prefs.remove(_kLastImportedMs);
  }
}

class GooglePersistedSession {
  final String email;
  final String? displayName;
  final String? accessToken;
  final String? spreadsheetId;
  final DateTime? lastSyncedAt;
  final DateTime? lastImportedAt;

  const GooglePersistedSession({
    required this.email,
    this.displayName,
    this.accessToken,
    this.spreadsheetId,
    this.lastSyncedAt,
    this.lastImportedAt,
  });
}
