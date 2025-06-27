#!/bin/bash
set -euo pipefail

LOG_FILE="test_results.log"
TMP_FILE="test_output.txt"
REPORT_FILE="test_summary.md"

rm -f "$LOG_FILE" "$TMP_FILE" "$REPORT_FILE"

echo "Running Cargo fmt..." | tee -a "$LOG_FILE"

PROJECT_ROOT=${GITHUB_WORKSPACE:-$(pwd)}
cd "$PROJECT_ROOT"

FAILED_TOTAL=0
PASSED_TOTAL=0
PIDS=()

# Declare manifest paths
COMMON_MANIFEST="src/common/Cargo.toml"
AGENT_MANIFEST="src/agent/Cargo.toml"
TOOLS_MANIFEST="src/tools/Cargo.toml"
APISERVER_MANIFEST="src/server/apiserver/Cargo.toml"
FILTERGATEWAY_MANIFEST="src/player/filtergateway/Cargo.toml"

# Run and parse test output
run_clippy() {
  local manifest="$1"
  local label="$2"
  local clippy_passed=false

  echo "Running fmt for $label ($manifest)" | tee -a "$LOG_FILE"

  if cargo fmt --manifest-path="$manifest" --all --check | tee "$TMP_FILE"; then
    echo "fmt for $label passed clean." | tee -a "$LOG_FILE"
    clippy_passed=true
  else
    echo "::error ::Clippy for $label failed! Found warnings/errors. Check logs." | tee -a "$LOG_FILE"
    # Capture relevant lines from TMP_FILE if needed for summary, or direct stdout/stderr
    # Example: Print only the warnings/errors to log, not the whole verbose output
    # grep -E "warning:|error:" "$TMP_FILE" | tee -a "$LOG_FILE"
  fi

  # Instead of PASSED_TOTAL/FAILED_TOTAL for *lints*, we track job success/failure
  if $clippy_passed; then
    echo "✅ fmt for $label: PASSED" >> "$REPORT_FILE"
  else
    echo "❌ fmt for $label: FAILED" >> "$REPORT_FILE"
    # Increment a counter for overall script failure
    (( FAILED_TOTAL++ )) # FAILED_TOTAL now represents number of manifests that failed clippy
  fi
}

# Run common clippy checks
if [[ -f "$COMMON_MANIFEST" ]]; then
  run_clippy "$COMMON_MANIFEST" "common"
else
  echo "::warning ::$COMMON_MANIFEST not found, skipping..."
fi

# Run apiserver clippy checks
if [[ -f "$APISERVER_MANIFEST" ]]; then
  run_clippy "$APISERVER_MANIFEST" "apiserver"
else
  echo "::warning ::$APISERVER_MANIFEST not found, skipping..."
fi

# Run tools clippy checks
if [[ -f "$TOOLS_MANIFEST" ]]; then
  run_clippy "$TOOLS_MANIFEST" "tools"
else
  echo "::warning ::$TOOLS_MANIFEST not found, skipping..."
fi

# Run agent clippy checks
if [[ -f "$AGENT_MANIFEST" ]]; then
  run_clippy "$AGENT_MANIFEST" "agent"
else
  echo "::warning ::$AGENT_MANIFEST not found, skipping..."
fi
!/bin/bash