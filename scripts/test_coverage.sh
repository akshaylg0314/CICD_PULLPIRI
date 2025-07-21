#!/bin/bash
set -euo pipefail

# === Path to Cargo.toml for each Rust subproject ===
COMMON_MANIFEST="src/common/Cargo.toml"
AGENT_MANIFEST="src/agent/Cargo.toml"
TOOLS_MANIFEST="src/tools/Cargo.toml"
APISERVER_MANIFEST="src/server/apiserver/Cargo.toml"
FILTERGATEWAY_MANIFEST="src/player/filtergateway/Cargo.toml"
ACTIONCONTROLLER_MANIFEST="src/player/actioncontroller/Cargo.toml"

# === Output setup ===
PROJECT_ROOT="$(pwd)"
COVERAGE_DIR="$PROJECT_ROOT/dist/coverage"
LOG_FILE="$COVERAGE_DIR/test_coverage_log.txt"

mkdir -p "$COVERAGE_DIR"
rm -f "$LOG_FILE"
touch "$LOG_FILE"

echo "🧪 Starting test coverage collection for individual crates..." | tee -a "$LOG_FILE"

MANIFESTS=(
    "$COMMON_MANIFEST"
    "$AGENT_MANIFEST"
    "$TOOLS_MANIFEST"
    "$APISERVER_MANIFEST"
    "$FILTERGATEWAY_MANIFEST"
    "$ACTIONCONTROLLER_MANIFEST"
)

# Ensure cargo-tarpaulin is installed
if ! command -v cargo-tarpaulin &>/dev/null; then
    echo "📦 Installing cargo-tarpaulin..." | tee -a "$LOG_FILE"
    cargo install cargo-tarpaulin
fi

# Enable nightly-only options temporarily
export RUSTC_BOOTSTRAP=1

for manifest in "${MANIFESTS[@]}"; do
    if [[ -f "$manifest" ]]; then
        crate_dir="$(dirname "$manifest")"
        crate_name="$(basename "$crate_dir")"
        crate_cov_dir="$COVERAGE_DIR/$crate_name"

        echo "📂 Running tarpaulin for $crate_name ($manifest)" | tee -a "$LOG_FILE"
        mkdir -p "$crate_cov_dir"

        (
            cd "$crate_dir"
            cargo tarpaulin \
              --out Html \
              --out Lcov \
              --out Xml \
              --output-dir "$crate_cov_dir" \
              2>&1 | tee -a "$LOG_FILE"
        )

        # Rename output files
        mv "$crate_cov_dir"/tarpaulin-report.html "$crate_cov_dir"/index.html 2>/dev/null || true
        mv "$crate_cov_dir"/lcov.info "$crate_cov_dir"/lcov.info 2>/dev/null || true
        mv "$crate_cov_dir"/cobertura.xml "$crate_cov_dir"/cobertura.xml 2>/dev/null || true
    else
        echo "::warning ::Manifest $manifest not found. Skipping..." | tee -a "$LOG_FILE"
    fi
done

echo "✅ All test coverage reports generated in: $COVERAGE_DIR" | tee -a "$LOG_FILE"
