#!/bin/bash
set -euo pipefail

# Set project root (absolute path)
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
    "src/common/Cargo.toml"
    "src/agent/Cargo.toml"
    "src/tools/Cargo.toml"
    "src/player/Cargo.toml"
)

# Global fallback template/config (optional default)
DEFAULT_TEMPLATE="$PROJECT_ROOT/src/server/about.hbs"
DEFAULT_CONFIG="$PROJECT_ROOT/src/server/about.toml"

# Ensure cargo-about is installed
if ! command -v cargo-about &>/dev/null; then
  echo "❗ cargo-about not found, installing..." | tee -a "$LOG_FILE"
  cargo install cargo-about
fi

# Loop through each manifest
for manifest in "${MANIFESTS[@]}"; do
  if [[ -f "$manifest" ]]; then
    crate_dir="$(dirname "$manifest")"
    label="$(basename "$crate_dir")"
    echo "📄 Generating license report for $label ($manifest)" | tee -a "$LOG_FILE"

    # Determine local config/template or fall back
    CONFIG="${crate_dir}/about.toml"
    TEMPLATE="${crate_dir}/about.hbs"

    [[ -f "$CONFIG" ]] || CONFIG="$DEFAULT_CONFIG"
    [[ -f "$TEMPLATE" ]] || TEMPLATE="$DEFAULT_TEMPLATE"

    echo "Using template: $TEMPLATE" | tee -a "$LOG_FILE"
    echo "Using config: $CONFIG" | tee -a "$LOG_FILE"

    # Output path
    output_path="$PROJECT_ROOT/dist/licenses/${label}_licenses.html"
    mkdir -p "$(dirname "$output_path")"

    (
      cd "$crate_dir"
      echo "🔧 Working in $(pwd), generating $output_path" | tee -a "$LOG_FILE"
      cargo about generate --config "$CONFIG" "$TEMPLATE" > "$output_path"
    )
  else
    echo "::warning ::Manifest $manifest not found, skipping..." | tee -a "$LOG_FILE"
  fi
done

echo "✅ License reports generated in dist/licenses" | tee -a "$LOG_FILE"
