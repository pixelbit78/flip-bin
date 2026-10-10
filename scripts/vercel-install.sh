#!/usr/bin/env bash
# Install a PINNED Flutter release (SPEC §12.8: --no-web-resources-cdn must exist).
set -euo pipefail

FLUTTER_VERSION="3.47.5"

FLUTTER_DIR="${FLUTTER_HOME:-$HOME/flutter}"
export PATH="$FLUTTER_DIR/bin:$PATH"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Cloning Flutter stable into $FLUTTER_DIR ..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$FLUTTER_DIR"
fi

flutter --version
flutter config --no-analytics
flutter precache --web
cd flipbin
flutter pub get
