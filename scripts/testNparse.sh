#!/bin/bash
set -euo pipefail

LOG_FILE="test_results.log"
TMP_FILE="test_output.txt"
TEST_REPORT_DIR="dist/tests"

mkdir -p "$TEST_REPORT_DIR"
rm -f "$LOG_FILE" "$TMP_FILE"

echo "Running Cargo Tests and Doctests with cargo-nextest..." | tee -a "$LOG_FILE"

PROJECT_ROOT=${GITHUB_WORKSPACE:-$(pwd)}
cd "$PROJECT_ROOT"

FAILED_TOTAL=0
PASSED_TOTAL=0
PIDS=()

# Manifest paths
declare -A MANIFESTS=(
  ["common"]="src/common/Cargo.toml"
  ["agent"]="src/agent/Cargo.toml"
  ["tools"]="src/tools/Cargo.toml"
  ["apiserver"]="src/server/apiserver/Cargo.toml"
  ["filtergateway"]="src/player/filtergateway/Cargo.toml"
  ["actioncontroller"]="src/player/actioncontroller/Cargo.toml"
)

# Check/install dependencies (cargo-nextest, cargo2junit)
command -v cargo-nextest >/dev/null || { echo "Installing cargo-nextest..."; cargo install cargo-nextest; }
command -v cargo2junit >/dev/null || { echo "Installing cargo2junit..."; cargo install cargo2junit; }

start_service() {
  local manifest="$1"
  local name="$2"
  echo "Starting $name component for testing..." | tee -a "$LOG_FILE"
  cargo run --manifest-path="$manifest" &>> "$LOG_FILE" &
  PIDS+=($!)
}

cleanup() {
  echo -e "\nCleaning up background services..." | tee -a "$LOG_FILE"
  kill "${PIDS[@]}" 2>/dev/null || true
}
trap cleanup EXIT

run_tests() {
  local manifest="$1"
  local label="$2"
  local report_file="$TEST_REPORT_DIR/${label}_test_report.xml"

  echo "Running unit/integration tests for $label ($manifest)" | tee -a "$LOG_FILE"
  if cargo nextest run --manifest-path="$manifest" --junit "$report_file" -- --test-threads=1 2>&1 | tee "$TMP_FILE"; then
    echo "Tests passed for $label" | tee -a "$LOG_FILE"
  else
    echo "::error ::Tests failed for $label! Check logs." | tee -a "$LOG_FILE"
  fi

  local passed=$(grep -oP '\d+(?= passed)' "$TMP_FILE" | awk '{sum += $1} END {print sum}')
  local failed=$(grep -oP '\d+(?= failed)' "$TMP_FILE" | awk '{sum += $1} END {print sum}')

  PASSED_TOTAL=$((PASSED_TOTAL + passed))
  FAILED_TOTAL=$((FAILED_TOTAL + failed))
}

run_doctests() {
  local manifest="$1"
  local label="$2"
  local json_file="target/doctest_${label}_results.json"
  local xml_file="$TEST_REPORT_DIR/${label}_doctest_report.xml"

  echo "Running doctests for $label ($manifest)" | tee -a "$LOG_FILE"

  RUSTC_BOOTSTRAP=1 cargo test --manifest-path="$manifest" --doc -- -Z unstable-options --format json --report-time 2> /dev/null | tee "$json_file"

  cat "$json_file" | cargo2junit > "$xml_file"

  local passed=$(jq '[.[] | select(.type == "test" and .event == "ok")] | length' "$json_file" 2>/dev/null || echo 0)
  local failed=$(jq '[.[] | select(.type == "test" and .event == "failed")] | length' "$json_file" 2>/dev/null || echo 0)

  echo "Doctests Passed for $label: $passed" | tee -a "$LOG_FILE"
  echo "Doctests Failed for $label: $failed" | tee -a "$LOG_FILE"

  PASSED_TOTAL=$((PASSED_TOTAL + passed))
  FAILED_TOTAL=$((FAILED_TOTAL + failed))
}

# Example: start any needed background services before running apiserver tests
start_service "${MANIFESTS[filtergateway]}" "filtergateway"
start_service "${MANIFESTS[agent]}" "nodeagent"
sleep 3

# Run tests + doctests for each manifest if file exists
for label in "${!MANIFESTS[@]}"; do
  manifest="${MANIFESTS[$label]}"
  if [[ -f "$manifest" ]]; then
    run_tests "$manifest" "$label"
    run_doctests "$manifest" "$label"
  else
    echo "::warning ::$manifest not found, skipping..." | tee -a "$LOG_FILE"
  fi
done

cleanup
PIDS=()
trap cleanup EXIT

echo "Total Tests Passed: $PASSED_TOTAL" | tee -a "$LOG_FILE"
echo "Total Tests Failed: $FAILED_TOTAL" | tee -a "$LOG_FILE"

if [[ "$FAILED_TOTAL" -gt 0 ]]; then
  echo "::error ::Some tests failed!" | tee -a "$LOG_FILE"
  exit 1
fi

echo "All tests passed successfully!" | tee -a "$LOG_FILE"
