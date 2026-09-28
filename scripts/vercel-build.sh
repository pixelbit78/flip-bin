#!/usr/bin/env bash
# Build Flutter web with base-href / (Vercel root, not GitHub Pages /flip-bin/).
set -euo pipefail

FLUTTER_DIR="${FLUTTER_HOME:-$HOME/flutter}"
export PATH="$FLUTTER_DIR/bin:$PATH"

cd flipbin
flutter build web --release --base-href /
