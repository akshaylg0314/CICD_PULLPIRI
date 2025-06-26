#!/bin/bash
set -euo pipefail

LOG_FILE="test_results.log"
TMP_FILE="test_output.txt"
REPORT_FILE="test_summary.md"

rm -f "$LOG_FILE" "$TMP_FILE" "$REPORT_FILE"

echo "Running Cargo Tests..." | tee -a "$LOG_FILE"

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

  echo "Running Clippy for $label ($manifest)" | tee -a "$LOG_FILE"

  if cargo clippy -vv --manifest-path="$manifest" --all-targets --all-features | tee "$TMP_FILE"; then
    echo "clippy passed for $label"
  else
    echo "::error ::clippy failed for $label! Check logs." | tee -a "$LOG_FILE"
  fi

  local passed
  local failed

  passed=$(grep -oP '\d+ passed' "$TMP_FILE" | awk '{sum += $1} END {print sum}')
  failed=$(grep -oP '\d+ failed' "$TMP_FILE" | awk '{sum += $1} END {print sum}')

  PASSED_TOTAL=$((PASSED_TOTAL + passed))
  FAILED_TOTAL=$((FAILED_TOTAL + failed))
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

