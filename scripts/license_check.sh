#!/bin/bash
set -euo pipefail

mkdir -p dist/licenses
LOG_FILE="dist/licenses/license_log.txt"
rm -f "$LOG_FILE"
touch "$LOG_FILE"

echo "🔍 Starting license checks..." | tee -a "$LOG_FILE"

MANIFESTS=(
  "src/common/Cargo.toml"
  "src/agent/Cargo.toml"
  "src/tools/Cargo.toml"
  "src/server/apiserver/Cargo.toml"
  "src/player/filtergateway/Cargo.toml"
  "src/player/actioncontroller/Cargo.toml"
)

TEMPLATE="about.hbs"
CONFIG="about.toml"

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
      cargo about generate --config "../../$CONFIG" "../../$TEMPLATE" > "../../dist/licenses/${label}_licenses.html"
    )
  else
    echo "::warning ::Manifest $manifest not found, skipping..." | tee -a "$LOG_FILE"
  fi
done

echo "✅ License reports generated in dist/licenses" | tee -a "$LOG_FILE"
