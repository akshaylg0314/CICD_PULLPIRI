#!/bin/bash
set -euo pipefail

# Create output directory
mkdir -p dist/licenses
LOG_FILE="dist/licenses/license_log.txt"
rm -f "$LOG_FILE"
touch "$LOG_FILE"

echo "🔍 Starting license checks..." | tee -a "$LOG_FILE"

# List of Cargo.toml files to check
MANIFESTS=(
    "src/server/apiserver/Cargo.toml"
    # Uncomment the below lines if you want to include them
    # "src/common/Cargo.toml"
    # "src/agent/Cargo.toml"
    # "src/tools/Cargo.toml"
    # "src/player/filtergateway/Cargo.toml"
    # "src/player/actioncontroller/Cargo.toml"
)

# Path to the config and template (update based on your project layout)
TEMPLATE="src/server/about.hbs"
CONFIG="src/server/about.toml"

echo "Using template: $TEMPLATE" | tee -a "$LOG_FILE"
echo "Using config: $CONFIG" | tee -a "$LOG_FILE"

# Ensure cargo-about is installed
if ! command -v cargo-about &>/dev/null; then
  echo "❗ cargo-about not found, installing..." | tee -a "$LOG_FILE"
  cargo install cargo-about
fi

# Run license generation for each manifest
for manifest in "${MANIFESTS[@]}"; do
  if [[ -f "$manifest" ]]; then
    label=$(basename "$(dirname "$manifest")")
    echo "📄 Generating license report for $label ($manifest)" | tee -a "$LOG_FILE"
    dir=$(dirname "$manifest")

    (
      cd "$dir"
      mkdir -p dist/licenses  # ensure the output dir exists inside the crate too
      cargo about generate --config "../../$CONFIG" "../../$TEMPLATE"
    )
  else
    echo "::warning ::Manifest $manifest not found, skipping..." | tee -a "$LOG_FILE"
  fi
done

echo "✅ License reports generated in dist/licenses" | tee -a "$LOG_FILE"