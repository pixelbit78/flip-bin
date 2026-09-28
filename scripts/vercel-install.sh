#!/usr/bin/env bash
# Install Flutter (stable) for Vercel Hobby builds, then resolve Dart deps.
set -euo pipefail

FLUTTER_DIR="${FLUTTER_HOME:-$HOME/flutter}"
export PATH="$FLUTTER_DIR/bin:$PATH"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Cloning Flutter stable into $FLUTTER_DIR ..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_DIR"
fi

flutter --version
flutter config --no-analytics
flutter precache --web
cd flipbin
flutter pub get
