#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/release/MathTutor-EMNLP2026-Demo-Package"
ZIP_PATH="$ROOT_DIR/release/MathTutor-EMNLP2026-Demo-Package.zip"

cd "$ROOT_DIR"

if [[ ! -d "$PACKAGE_DIR" ]]; then
  echo "Package folder does not exist: $PACKAGE_DIR" >&2
  exit 1
fi

rm -f "$ZIP_PATH"

cd "$ROOT_DIR/release"
zip -r "MathTutor-EMNLP2026-Demo-Package.zip" "MathTutor-EMNLP2026-Demo-Package" \
  -x "*.env" \
  -x ".env" \
  -x "*/.env" \
  -x ".git/*" \
  -x "*/.git/*" \
  -x ".DS_Store" \
  -x "*/.DS_Store" \
  -x "node_modules/*" \
  -x "*/node_modules/*" \
  -x "build/*" \
  -x "*/build/*" \
  -x "DerivedData/*" \
  -x "*/DerivedData/*" \
  -x "*.xcuserstate" \
  -x "*.xcuserdata/*" \
  -x "*/xcuserdata/*" \
  -x "secrets/*" \
  -x "*/secrets/*" \
  -x "*secret*" \
  -x "*Secret*" \
  -x "*token*" \
  -x "*Token*" \
  -x "*key*" \
  -x "*Key*" \
  -x "*.md"
