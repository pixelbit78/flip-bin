// QA-env assertions (QZ-06, QZ-07, QZ-01). Only meaningful with
//   flutter test --dart-define=FLIPBIN_ENV=qa test/config/qa_env_test.dart
// In the default prod run these are skipped.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/config/env.dart';
import 'package:flipbin/providers/sync_provider.dart';
import 'package:flipbin/services/google_sheets_service.dart';
import 'package:flipbin/widgets/env_banner.dart';

void main() {
  const skip = kIsProd ? 'run with --dart-define=FLIPBIN_ENV=qa' : null;

  test('Google service constructor throws in QA (QZ-06)', () {
    expect(() => GoogleSheetsService(), throwsA(anything));
  }, skip: skip);

  test('googleSheetsServiceProvider throws in QA', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(() => c.read(googleSheetsServiceProvider), throwsA(anything));
  }, skip: skip);

  test('storage isolation names (QZ-07)', () {
    expect(Env.dbName, 'flipbin_qa');
    expect(Env.prefsKey('flipbin.camera.allowed'), 'qa.flipbin.camera.allowed');
  }, skip: skip);

  testWidgets('QA banner shown (QZ-01)', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: EnvBanner(child: Text('app'))));
    expect(find.text('QA build — local data only, not connected to Google'),
        findsOneWidget);
  }, skip: skip != null);
}
