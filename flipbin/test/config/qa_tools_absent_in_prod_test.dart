// Default (prod) build: QA tools and the QA banner are absent (QT-05).
// Run the QA counterpart with:
//   flutter test --dart-define=FLIPBIN_ENV=qa test/config/qa_env_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbin/config/env.dart';
import 'package:flipbin/screens/settings/qa_settings_screen.dart';
import 'package:flipbin/widgets/env_banner.dart';

void main() {
  test('default env is prod', () {
    expect(kFlipBinEnv, 'prod');
    expect(kIsProd, isTrue);
    expect(Env.dbName, 'flipbin');
    expect(Env.prefsKey('flipbin.x'), 'flipbin.x');
  });

  testWidgets('no QA banner in prod', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EnvBanner(child: Text('app'))));
    expect(find.byKey(const Key('qaBanner')), findsNothing);
  });

  testWidgets('QaSettingsScreen does not render QaToolsSection in prod',
      (tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: QaSettingsScreen())));
    expect(find.byType(QaToolsSection), findsNothing);
  }, skip: !kIsProd);
}
