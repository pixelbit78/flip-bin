#!/usr/bin/env bash
# Vercel build entry (vercel.json buildCommand) for BOTH projects.
#
# vercel.json overrides dashboard build settings, so the project is picked
# from Vercel's system env VERCEL_PROJECT_PRODUCTION_URL — fail closed:
#   flip-bin.vercel.app     → PROD build (FLIPBIN_ENV=prod, Google enabled)
#   flip-bin-qa.vercel.app  → QA build via vercel-build-qa.sh (no Google)
#   anything else on Vercel → build FAILS (never silently ships prod or QA)
# Off Vercel (local), the default is prod, as before.
set -euo pipefail

if [ -n "${VERCEL:-}" ]; then
  case "${VERCEL_PROJECT_PRODUCTION_URL:-}" in
    flip-bin.vercel.app) ;;
    flip-bin-qa.vercel.app) exec bash scripts/vercel-build-qa.sh ;;
    *)
      echo "Unknown Vercel project '${VERCEL_PROJECT_PRODUCTION_URL:-}'; refusing to build." >&2
      exit 1 ;;
  esac
fi

FLUTTER_DIR="${FLUTTER_HOME:-$HOME/flutter}"
export PATH="$FLUTTER_DIR/bin:$PATH"

cd flipbin
flutter build web --release --base-href / \
  --dart-define=FLIPBIN_ENV=prod \
  --no-web-resources-cdn
cd ..
bash scripts/check-prod-artifact.sh flipbin/build/web
