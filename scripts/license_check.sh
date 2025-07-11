#!/bin/bash
set -euo pipefail

# Define base paths
PROJECT_ROOT=${GITHUB_WORKSPACE:-$(pwd)}
LICENSE_DIR="$PROJECT_ROOT/dist/licenses"
LOG_FILE="$LICENSE_DIR/license_log.txt"

# Prepare output directory
mkdir -p "$LICENSE_DIR"
rm -f "$LOG_FILE"
touch "$LOG_FILE"

echo "🔍 Starting license checks..." | tee -a "$LOG_FILE"

# Manifests to process
MANIFESTS=(
#   "src/common/Cargo.toml"
#   "src/agent/Cargo.toml"
#   "src/tools/Cargo.toml"
    "src/server/apiserver/Cargo.toml"
#   "src/player/filtergateway/Cargo.toml"
#   "src/player/actioncontroller/Cargo.toml"
)

# Use absolute paths for template/config
TEMPLATE="$PROJECT_ROOT/about.hbs"
CONFIG="$PROJECT_ROOT/about.toml"

# Install cargo-about if needed
if ! command -v cargo-about &>/dev/null; then
  echo "❗ cargo-about not found, installing..." | tee -a "$LOG_FILE"
  cargo install cargo-about
fi

for manifest in "${MANIFESTS[@]}"; do
  if [[ -f "$manifest" ]]; then
    label=$(basename "$(dirname "$manifest")")
    echo "📄 Generating license report for $label ($manifest)" | tee -a "$LOG_FILE"
    manifest_dir=$(dirname "$manifest")

    (
      cd "$PROJECT_ROOT/$manifest_dir"
      cargo about generate --config "$CONFIG" "$TEMPLATE" > "$LICENSE_DIR/${label}_licenses.html"
    )
  else
    echo "::warning ::Manifest $manifest not found, skipping..." | tee -a "$LOG_FILE"
  fi
done

echo "✅ License reports generated in dist/licenses" | tee -a "$LOG_FILE"
