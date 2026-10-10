import 'package:flipbin/config/env.dart';

/// Skip reason for prod-only suites (Google services, prod-absence checks).
/// Null in prod so they run; in QA builds (`--dart-define=FLIPBIN_ENV=qa`)
/// they report as skipped instead of failing.
const String? prodOnlySkip =
    kIsProd ? null : 'prod-only: skipped when FLIPBIN_ENV=$kFlipBinEnv';

/// Inverse: suites that only make sense in a non-prod build.
const String? qaOnlySkip = kIsQa ? null : 'qa-only: run with FLIPBIN_ENV=qa';
