#!/usr/bin/env bash
# Fails if QA-only code leaked into the prod artifact (SPEC §12.9, QT-05).
set -euo pipefail
DIR="${1:-flipbin/build/web}"
fail=0
for pat in 'Load legacy v1 fixture' 'QA build — local data only' 'qa.flipbin.'; do
  if grep -rqF -- "$pat" "$DIR/main.dart.js"; then
    echo "Prod artifact check FAILED: '$pat' found in main.dart.js"; fail=1
  fi
done
if [ -d "$DIR/assets/qa" ]; then echo "Prod artifact check FAILED: assets/qa present"; fail=1; fi
if ! grep -qF 'google-signin-client_id' "$DIR/index.html"; then
  echo "Prod artifact check FAILED: Google sign-in meta tag missing"; fail=1
fi
[ "$fail" = 0 ] && echo "Prod artifact check passed ($DIR)"
exit $fail
