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
  });

  group('kAutoBackupInterval', () {
    test('is 24 hours', () {
      expect(kAutoBackupInterval, const Duration(hours: 24));
    });
  });
}
