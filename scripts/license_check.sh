#!/bin/bash
set -euo pipefail

ABOUT_TOML="${1:-src/server/about.toml}"
ABOUT_HBS="${2:-src/server/about.hbs}"

mkdir -p dist/licenses
LOG_FILE="dist/licenses/license_log.txt"
rm -f "$LOG_FILE"
touch "$LOG_FILE"

echo "🔍 Starting license checks..." | tee -a "$LOG_FILE"

MANIFESTS=(
  "src/server/apiserver/Cargo.toml"
)

if ! command -v cargo-about &>/dev/null; then
  echo "❗ cargo-about not found, installing..." | tee -a "$LOG_FILE"
  cargo install cargo-about
fi

for manifest in "${MANIFESTS[@]}"; do
  if [[ -f "$manifest" ]]; then
    label=$(basename "$(dirname "$manifest")")
    echo "📄 Generating license report for $label ($manifest)" | tee -a "$LOG_FILE"
    dir=$(dirname "$manifest")
    (
      cd "$dir"
      cargo about generate --config "$ABOUT_TOML" "$ABOUT_HBS" > "$(realpath "dist/licenses/${label}_licenses.html")"
    )
  else
    echo "::warning ::Manifest $manifest not found, skipping..." | tee -a "$LOG_FILE"
  fi
done

echo "✅ License reports generated in dist/licenses" | tee -a "$LOG_FILE"
