#!/usr/bin/env bash
# Fails if the QA web artifact contains Google sign-in / API / CDN strings
# (SPEC §12.2 layer 6, §12.8, QZ-08).
set -euo pipefail
DIR="${1:-flipbin/build/web}"
fail=0
check() {
  local pat="$1"
  local hits
  hits=$(grep -rlF --exclude-dir=canvaskit -- "$pat" "$DIR" || true)
  if [ -n "$hits" ]; then
    echo "QA artifact check FAILED: '$pat' found in:"; echo "$hits"; fail=1
  fi
}
check 'google-signin-client_id'
check '300135141102-ijqefa0enb2pm08i5kkgdnfbmpgp46tb'
check 'accounts.google.com'
check 'sheets.googleapis.com'
check 'www.googleapis.com/drive'
check 'fonts.googleapis.com'
check 'googleusercontent.com'
check 'gsi/client'
# gstatic: flutter.js and the engine carry the CDN URLs only as *defaults*
# used when no override is configured. Require the overrides instead.
if ! grep -qF 'canvasKitBaseUrl: "canvaskit/"' "$DIR/flutter_bootstrap.js" ||
   ! grep -qF 'fontFallbackBaseUrl: "assets/fallback_fonts/"' "$DIR/flutter_bootstrap.js"; then
  echo "QA artifact check FAILED: canvasKitBaseUrl/fontFallbackBaseUrl overrides missing"; fail=1
fi
hits=$(grep -rlF 'gstatic.com' "$DIR" --exclude=flutter.js --exclude=flutter_bootstrap.js --exclude=main.dart.js --exclude-dir=canvaskit || true)
if [ -n "$hits" ]; then echo "QA artifact check FAILED: gstatic.com in $hits"; fail=1; fi
if [ "$(grep -o 'gstatic.com' "$DIR/main.dart.js" | wc -l)" -gt 1 ]; then
  echo "QA artifact check FAILED: unexpected gstatic.com references in main.dart.js"; fail=1
fi
if [ ! -f "$DIR/canvaskit/canvaskit.wasm" ]; then
  echo "QA artifact check FAILED: self-hosted canvaskit missing"; fail=1
fi
[ "$fail" = 0 ] && echo "QA artifact check passed ($DIR)"
exit $fail
