import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flipbin/providers/sync_provider.dart';
import 'package:flipbin/services/google_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GoogleSessionStore auto-backup prefs', () {
    test('defaults to disabled and persists toggle', () async {
      final store = GoogleSessionStore();
      expect(await store.loadAutoBackupEnabled(), isFalse);
      await store.saveAutoBackupEnabled(true);
      expect(await store.loadAutoBackupEnabled(), isTrue);
      await store.saveAutoBackupEnabled(false);
      expect(await store.loadAutoBackupEnabled(), isFalse);
    });

    test('clearAccessTokenOnly keeps email and spreadsheet hints', () async {
      final store = GoogleSessionStore();
      await store.saveSignedInUser(
        email: 'steve@example.com',
        displayName: 'Steve',
      );
      await store.saveAccessToken('tok-abc');
      await store.saveSpreadsheetId('sheet-1');

      await store.clearAccessTokenOnly();

      final session = await store.load();
      expect(session, isNotNull);
      expect(session!.email, 'steve@example.com');
      expect(session.displayName, 'Steve');
      expect(session.spreadsheetId, 'sheet-1');
      expect(session.accessToken, isNull);
    });
  });

  group('SyncState auto-backup fields', () {
    test('copyWith preserves and updates autoBackupEnabled', () {
      const base = SyncState();
      expect(base.autoBackupEnabled, isFalse);
      final on = base.copyWith(autoBackupEnabled: true);
      expect(on.autoBackupEnabled, isTrue);
      final off = on.copyWith(autoBackupEnabled: false);
      expect(off.autoBackupEnabled, isFalse);
    });

    test('needsReauth and authNotice default off and copyWith works', () {
      const base = SyncState();
      expect(base.needsReauth, isFalse);
      expect(base.authNotice, isNull);

      final flagged = base.copyWith(
        needsReauth: true,
        authNotice: 'Sign in again to keep backups running.',
      );
      expect(flagged.needsReauth, isTrue);
      expect(flagged.authNotice, contains('Sign in again'));

      final cleared = flagged.copyWith(
        needsReauth: false,
        clearAuthNotice: true,
      );
      expect(cleared.needsReauth, isFalse);
      expect(cleared.authNotice, isNull);
    });
  });

  group('kAutoBackupInterval', () {
    test('is 24 hours', () {
      expect(kAutoBackupInterval, const Duration(hours: 24));
    });
  });

  group('isGoogleAuthFailure', () {
    test('detects Drive HTTP 401 permission denied', () {
      expect(
        isGoogleAuthFailure(
          Exception(
            'Google Drive permission denied while searching for '
            '"FlipBin Export" (HTTP 401). Sign out and sign in again',
          ),
        ),
        isTrue,
      );
    });

    test('detects generic please-sign-in', () {
      expect(
        isGoogleAuthFailure(Exception('Please sign in with Google first.')),
        isTrue,
      );
    });

    test('ignores unrelated export errors', () {
      expect(
        isGoogleAuthFailure(Exception('Network unreachable')),
        isFalse,
      );
    });
  });
}
