#!/bin/bash
set -euo pipefail

# Set project root (always absolute)
PROJECT_ROOT="$(pwd)"

# Prepare output directory
mkdir -p "$PROJECT_ROOT/dist/licenses"
LOG_FILE="$PROJECT_ROOT/dist/licenses/license_log.txt"
rm -f "$LOG_FILE"
touch "$LOG_FILE"

echo "🔍 Starting license checks..." | tee -a "$LOG_FILE"

# List of Cargo.toml files to check
MANIFESTS=(
    "src/server/apiserver/Cargo.toml"
    # "src/common/Cargo.toml"
    # "src/agent/Cargo.toml"
    # "src/tools/Cargo.toml"
    # "src/player/filtergateway/Cargo.toml"
    # "src/player/actioncontroller/Cargo.toml"
)

# Template and config (relative to project root)
TEMPLATE="$PROJECT_ROOT/src/server/about.hbs"
CONFIG="$PROJECT_ROOT/src/server/about.toml"

echo "Using template: $TEMPLATE" | tee -a "$LOG_FILE"
echo "Using config: $CONFIG" | tee -a "$LOG_FILE"

# Ensure cargo-about is installed
if ! command -v cargo-about &>/dev/null; then
  echo "❗ cargo-about not found, installing..." | tee -a "$LOG_FILE"
  cargo install cargo-about
fi

# Loop through each Cargo.toml
for manifest in "${MANIFESTS[@]}"; do
  if [[ -f "$manifest" ]]; then
    label=$(basename "$(dirname "$manifest")")
    echo "📄 Generating license report for $label ($manifest)" | tee -a "$LOG_FILE"
    dir=$(dirname "$manifest")

    # Final output path
    output_path="$PROJECT_ROOT/dist/licenses/${label}_licenses.html"
    mkdir -p "$(dirname "$output_path")"  # Just in case

    (
      cd "$dir"
      echo "🔧 Working in $(pwd), generating $output_path" | tee -a "$LOG_FILE"
      cargo about generate --config "$CONFIG" "$TEMPLATE" > "$output_path"
    )
  else
    echo "::warning ::Manifest $manifest not found, skipping..." | tee -a "$LOG_FILE"
  fi
done

echo "✅ License reports generated in dist/licenses" | tee -a "$LOG_FILE"
