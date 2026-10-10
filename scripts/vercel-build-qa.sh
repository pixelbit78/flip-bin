#!/usr/bin/env bash
# QA build for flip-bin-qa.vercel.app (SPEC §12). FLIPBIN_ENV=qa is HARDCODED
# here — never taken from a dashboard env var — so a QA deploy can't
# accidentally become a Google-enabled prod build.
set -euo pipefail

FLUTTER_DIR="${FLUTTER_HOME:-$HOME/flutter}"
export PATH="$FLUTTER_DIR/bin:$PATH"

ROOT="$(pwd)"
# Build from a scratch copy with the Google code COMPILED OUT: the Google
# packages are removed from pubspec (so no Google web plugin is registered)
# and google_sheets_service.dart is replaced by the throwing QA stub.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
tar -C "$ROOT" --exclude='flipbin/build' --exclude='flipbin/.dart_tool' -cf - flipbin | tar -C "$WORK" -xf -
cd "$WORK/flipbin"
python3 - <<'PY'
import re
p = 'pubspec.yaml'
s = open(p).read()
for dep in ('googleapis', 'google_sign_in', 'extension_google_sign_in_as_googleapis_auth'):
    s, n = re.subn(r'^  %s:.*\n' % dep, '', s, flags=re.M)
    if n != 1:
        raise SystemExit('could not remove %s from pubspec' % dep)
open(p, 'w').write(s)
PY
cp lib/services/qa_stubs/google_sheets_service_stub.dart lib/services/google_sheets_service.dart
if grep -rlE "package:(google_sign_in|googleapis|extension_google_sign_in)" lib; then
  echo "Google package import remains in lib/ (above); refusing QA build" >&2
  exit 1
fi
flutter pub get
flutter build web --release --base-href / \
  --dart-define=FLIPBIN_ENV=qa \
  --no-web-resources-cdn

OUT=build/web
# 1. Strip the Google sign-in meta tag block.
python3 - "$OUT/index.html" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s2 = re.sub(r'\s*<!-- GOOGLE_META_START.*?GOOGLE_META_END -->', '', s, flags=re.S)
if s2 == s:
    sys.exit('GOOGLE_META block not found in index.html')
s2 = s2.replace('<title>FlipBin</title>', '<title>FlipBin QA</title>')
s2 = s2.replace('content="FlipBin">', 'content="FlipBin QA">')
open(p, 'w').write(s2)
PY
# 2. Distinct PWA identity.
cp web/manifest.qa.json "$OUT/manifest.json"
cp web/icons-qa/* "$OUT/icons/"
rm -rf "$ROOT/flipbin/build/web"
mkdir -p "$ROOT/flipbin/build"
cp -r "$OUT" "$ROOT/flipbin/build/web"
cd "$ROOT"
# 3. Fail the build if anything Google remains (SPEC §12.2 layer 6).
bash scripts/check-qa-artifact.sh flipbin/build/web
