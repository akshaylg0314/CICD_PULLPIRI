#!/bin/bash
set -euo pipefail

LOG_FILE="test_results.log"
TMP_FILE="test_output.txt"
TEST_REPORT_DIR="dist/tests"

mkdir -p "$TEST_REPORT_DIR"
rm -f "$LOG_FILE" "$TMP_FILE"

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
ACTIONCONTROLLER_MANIFEST="src/player/actioncontroller/Cargo.toml"

# Start background service and save its PID
start_service() {
  local manifest="$1"
  local name="$2"

  echo "Starting $name component for testing..." | tee -a "$LOG_FILE"
  cargo run --manifest-path="$manifest" &>> "$LOG_FILE" &
  PIDS+=($!)
}

# Cleanup background processes on exit
cleanup() {
  echo -e "\nCleaning up background services..." | tee -a "$LOG_FILE"
  kill "${PIDS[@]}" 2>/dev/null || true
}
trap cleanup EXIT

# Run tests and generate JUnit XML report with cargo nextest
run_tests() {
  local manifest="$1"
  local label="$2"
  local report_file="$TEST_REPORT_DIR/${label}_test_report.xml"

  echo "Running tests for $label ($manifest)" | tee -a "$LOG_FILE"

  if cargo nextest run --manifest-path="$manifest" --junit "$report_file" -- --test-threads=1 2>&1 | tee "$TMP_FILE"; then
    echo "Tests passed for $label" | tee -a "$LOG_FILE"
  else
    echo "::error ::Tests failed for $label! Check logs." | tee -a "$LOG_FILE"
  fi

  # Parse test summary counts
  local passed=$(grep -oP '\d+(?= passed)' "$TMP_FILE" | awk '{sum += $1} END {print sum}')
  local failed=$(grep -oP '\d+(?= failed)' "$TMP_FILE" | awk '{sum += $1} END {print sum}')

  # Defaults if empty
  passed=${passed:-0}
  failed=${failed:-0}

  PASSED_TOTAL=$((PASSED_TOTAL + passed))
  FAILED_TOTAL=$((FAILED_TOTAL + failed))
}

# Run tests in sequence

if [[ -f "$COMMON_MANIFEST" ]]; then
  run_tests "$COMMON_MANIFEST" "common"
else
  echo "::warning ::$COMMON_MANIFEST not found, skipping..." | tee -a "$LOG_FILE"
fi

start_service "$FILTERGATEWAY_MANIFEST" "filtergateway"
start_service "$AGENT_MANIFEST" "nodeagent"

sleep 3

if [[ -f "$APISERVER_MANIFEST" ]]; then
  run_tests "$APISERVER_MANIFEST" "apiserver"
else
  echo "::warning ::$APISERVER_MANIFEST not found, skipping..." | tee -a "$LOG_FILE"
fi

cleanup
PIDS=()
trap cleanup EXIT

if [[ -f "$TOOLS_MANIFEST" ]]; then
  run_tests "$TOOLS_MANIFEST" "tools"
else
  echo "::warning ::$TOOLS_MANIFEST not found, skipping..." | tee -a "$LOG_FILE"
fi

if [[ -f "$AGENT_MANIFEST" ]]; then
  run_tests "$AGENT_MANIFEST" "agent"
else
  echo "::warning ::$AGENT_MANIFEST not found, skipping..." | tee -a "$LOG_FILE"
fi

# Uncomment and enable when ready
# if [[ -f "$FILTERGATEWAY_MANIFEST" ]]; then
#   run_tests "$FILTERGATEWAY_MANIFEST" "filtergateway"
# else
#   echo "::warning ::$FILTERGATEWAY_MANIFEST not found, skipping..." | tee -a "$LOG_FILE"
# fi

# if [[ -f "$ACTIONCONTROLLER_MANIFEST" ]]; then
#   run_tests "$ACTIONCONTROLLER_MANIFEST" "actioncontroller"
# else
#   echo "::warning ::$ACTIONCONTROLLER_MANIFEST not found, skipping..." | tee -a "$LOG_FILE"
# fi

echo "Tests Passed: $PASSED_TOTAL" | tee -a "$LOG_FILE"
echo "Tests Failed: $FAILED_TOTAL" | tee -a "$LOG_FILE"

if [[ "$FAILED_TOTAL" -gt 0 ]]; then
  echo "::error ::Some tests failed!" | tee -a "$LOG_FILE"
  exit 1
fi

echo "All tests passed successfully!" | tee -a "$LOG_FILE"
