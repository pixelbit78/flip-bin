/// Build-time environment (SPEC §12.1).
///
/// `--dart-define=FLIPBIN_ENV=qa|prod`, default `prod`. Any value other than
/// `prod` is treated as not-prod (fail closed: no Google).
const String kFlipBinEnv =
    String.fromEnvironment('FLIPBIN_ENV', defaultValue: 'prod');
const bool kIsProd = kFlipBinEnv == 'prod';
const bool kIsQa = !kIsProd;

class Env {
  Env._();

  /// Web IndexedDB / native sqlite base name.
  static const String dbName = kIsProd ? 'flipbin' : 'flipbin_$kFlipBinEnv';

  /// Prefs key namespacing: `flipbin.x` in prod, `qa.flipbin.x` otherwise.
  static String prefsKey(String key) => kIsProd ? key : 'qa.$key';

  static const String appTitle = kIsProd ? 'FlipBin' : 'FlipBin QA';

  static const String bannerText = kFlipBinEnv == 'qa'
      ? 'QA build — local data only, not connected to Google'
      : 'Unknown env ($kFlipBinEnv) — local data only, not connected to Google';
}
