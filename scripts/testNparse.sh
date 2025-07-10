#!/bin/bash
set -euo pipefail

LOG_FILE="test_results.log"
TMP_FILE="test_output.txt"
TEST_REPORT_DIR="dist/tests"

mkdir -p "$TEST_REPORT_DIR"
rm -f "$LOG_FILE" "$TMP_FILE"

echo "📦 Running Cargo Tests with Doctests..." | tee -a "$LOG_FILE"

PROJECT_ROOT=${GITHUB_WORKSPACE:-$(pwd)}
cd "$PROJECT_ROOT"

FAILED_TOTAL=0
PASSED_TOTAL=0
PIDS=()

# Manifest paths
COMMON_MANIFEST="src/common/Cargo.toml"
AGENT_MANIFEST="src/agent/Cargo.toml"
TOOLS_MANIFEST="src/tools/Cargo.toml"
APISERVER_MANIFEST="src/server/apiserver/Cargo.toml"
FILTERGATEWAY_MANIFEST="src/player/filtergateway/Cargo.toml"
ACTIONCONTROLLER_MANIFEST="src/player/actioncontroller/Cargo.toml"

# Start background component
start_service() {
  local manifest="$1"
  local name="$2"

  echo "🚀 Starting $name service..." | tee -a "$LOG_FILE"
  cargo run --manifest-path="$manifest" &>> "$LOG_FILE" &
  PIDS+=($!)
}

# Cleanup services on exit
cleanup() {
  echo -e "\n🧹 Cleaning up services..." | tee -a "$LOG_FILE"
  kill "${PIDS[@]}" 2>/dev/null || true
}
trap cleanup EXIT

# Run tests with nextest and generate JUnit + doctest report
run_tests() {
  local manifest="$1"
  local label="$2"

  # Skip tests for filtergateway
  if [[ "$label" == "filtergateway" ]]; then
    echo "⚠️ Skipping tests for $label" | tee -a "$LOG_FILE"
    return
  fi

  # Skip tests for actioncontroller
  if [[ "$label" == "actioncontroller" ]]; then
    echo "⚠️ Skipping tests for $label" | tee -a "$LOG_FILE"
    return
  fi

  local report_file="$TEST_REPORT_DIR/${label}_test_report.xml"
  local doc_file="$TEST_REPORT_DIR/${label}_doctest_report.xml"

  echo "🧪 Running tests for $label ($manifest)" | tee -a "$LOG_FILE"

  if cargo nextest run --manifest-path="$manifest" --junit "$report_file" -- --test-threads=1 2>&1 | tee "$TMP_FILE"; then
    echo "✅ Tests passed for $label" | tee -a "$LOG_FILE"
  else
    echo "::error ::Tests failed for $label! Check logs." | tee -a "$LOG_FILE"
  fi

  # Run doctests and convert to JUnit format
  if RUSTC_BOOTSTRAP=1 cargo test --manifest-path="$manifest" --doc -- -Z unstable-options --format json | tee "doctest-output.json"; then
    cat doctest-output.json | cargo2junit > "$doc_file"
    rm -f doctest-output.json
  else
    echo "::error ::Doctests failed for $label" | tee -a "$LOG_FILE"
  fi

  # Count results
  local passed=$(grep -oP '\d+(?= passed)' "$TMP_FILE" | awk '{s+=$1} END {print s}')
  local failed=$(grep -oP '\d+(?= failed)' "$TMP_FILE" | awk '{s+=$1} END {print s}')
  PASSED_TOTAL=$((PASSED_TOTAL + ${passed:-0}))
  FAILED_TOTAL=$((FAILED_TOTAL + ${failed:-0}))
}

# Run selected modules

[[ -f "$COMMON_MANIFEST" ]] && run_tests "$COMMON_MANIFEST" "common" || echo "::warning ::$COMMON_MANIFEST not found"
start_service "$FILTERGATEWAY_MANIFEST" "filtergateway"
start_service "$AGENT_MANIFEST" "nodeagent"

sleep 3

[[ -f "$APISERVER_MANIFEST" ]] && run_tests "$APISERVER_MANIFEST" "apiserver" || echo "::warning ::$APISERVER_MANIFEST not found"
cleanup
PIDS=()
trap cleanup EXIT

[[ -f "$TOOLS_MANIFEST" ]] && run_tests "$TOOLS_MANIFEST" "tools" || echo "::warning ::$TOOLS_MANIFEST not found"
[[ -f "$AGENT_MANIFEST" ]] && run_tests "$AGENT_MANIFEST" "agent" || echo "::warning ::$AGENT_MANIFEST not found"
[[ -f "$ACTIONCONTROLLER_MANIFEST" ]] && run_tests "$ACTIONCONTROLLER_MANIFEST" "actioncontroller" || echo "::warning ::$ACTIONCONTROLLER_MANIFEST not found"

# Summary
echo "✅ Tests Passed: $PASSED_TOTAL" | tee -a "$LOG_FILE"
echo "❌ Tests Failed: $FAILED_TOTAL" | tee -a "$LOG_FILE"

if [[ "$FAILED_TOTAL" -gt 0 ]]; then
  echo "::error ::Some tests failed!" | tee -a "$LOG_FILE"
  exit 1
fi

echo "🎉 All tests passed!" | tee -a "$LOG_FILE"
