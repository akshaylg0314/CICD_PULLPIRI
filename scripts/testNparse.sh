#!/bin/bash
set -euo pipefail

LOG_FILE="test_results.log"
TMP_FILE="test_output.txt"
mkdir -p dist/tests target
REPORT_FILE="dist/tests/test_summary.xml"

# Clean up old logs and reports before starting
rm -f "$LOG_FILE" "$TMP_FILE" "$REPORT_FILE"

echo "Running Cargo Tests..." | tee -a "$LOG_FILE"

# Use GitHub workspace if available, else current directory
PROJECT_ROOT=${GITHUB_WORKSPACE:-$(pwd)}
cd "$PROJECT_ROOT"

FAILED_TOTAL=0
PASSED_TOTAL=0
PIDS=()  # Array to hold background service PIDs

# Declare manifest paths for each crate/component
COMMON_MANIFEST="src/common/Cargo.toml"
AGENT_MANIFEST="src/agent/Cargo.toml"
TOOLS_MANIFEST="src/tools/Cargo.toml"
APISERVER_MANIFEST="src/server/apiserver/Cargo.toml"
FILTERGATEWAY_MANIFEST="src/player/filtergateway/Cargo.toml"
ACTIONCONTROLLER_MANIFEST="src/player/actioncontroller/Cargo.toml"

# Function to start a component as background service (for e.g. dependent services)
start_service() {
  local manifest="$1"
  local name="$2"
  echo "Starting $name component for testing..." | tee -a "$LOG_FILE"
  # Run the binary in background, append stdout/stderr to log
  cargo run --manifest-path="$manifest" &>> "$LOG_FILE" &
  PIDS+=($!)  # Store PID for later cleanup
}

# Cleanup function to kill any background services started by the script
cleanup() {
  echo -e "\nCleaning up background services..." | tee -a "$LOG_FILE"
  if [[ ${#PIDS[@]} -gt 0 ]]; then
    for pid in "${PIDS[@]}"; do
      if kill -0 "$pid" &>/dev/null; then
        kill "$pid" 2>/dev/null || echo "⚠️ Failed to kill process $pid"
      fi
    done
  fi
}
trap cleanup EXIT  # Ensure cleanup on script exit

# Run tests for a given crate manifest, parse JSON output and generate JUnit XML if possible
run_tests() {
  local manifest="$1"
  local label="$2"
  local output_json="target/${label}_test_output.json"
  local report_xml="dist/tests/${label}_results.xml"

  echo "Running tests for $label ($manifest)" | tee -a "$LOG_FILE"

  # Run tests with JSON output, also enabling unstable formatting options (may require nightly)
  if RUSTC_BOOTSTRAP=1 cargo test --manifest-path="$manifest" -- -Z unstable-options --format json | tee "$output_json"; then
    echo "✅ Tests passed for $label" | tee -a "$LOG_FILE"
  else
    echo "::error ::❌ Tests failed for $label! Check logs." | tee -a "$LOG_FILE"
  fi

  if [[ -f "$output_json" ]]; then
    # Aggregate passed/failed counts from JSON output using grep + awk
    passed=$(grep -oP '\d+ passed' "$output_json" | awk '{sum += $1} END {print sum}')
    failed=$(grep -oP '\d+ failed' "$output_json" | awk '{sum += $1} END {print sum}')
    PASSED_TOTAL=$((PASSED_TOTAL + passed))
    FAILED_TOTAL=$((FAILED_TOTAL + failed))

    # Convert JSON test results to JUnit XML format if cargo2junit is available
    if command -v cargo2junit &>/dev/null; then
      cargo2junit < "$output_json" > "$report_xml"
    else
      echo "::warning ::cargo2junit not installed, skipping XML conversion"
    fi
  else
    echo "::warning ::No test output JSON found for $label"
  fi
}

# Run tests for the common crate if manifest exists
[[ -f "$COMMON_MANIFEST" ]] && run_tests "$COMMON_MANIFEST" "common" || echo "::warning ::$COMMON_MANIFEST not found, skipping..."

# Start services required for apiserver tests
start_service "$FILTERGATEWAY_MANIFEST" "filtergateway"
start_service "$AGENT_MANIFEST" "nodeagent"

sleep 3  # Give services some time to start before testing

# Run tests for apiserver crate
[[ -f "$APISERVER_MANIFEST" ]] && run_tests "$APISERVER_MANIFEST" "apiserver" || echo "::warning ::$APISERVER_MANIFEST not found, skipping..."

# Cleanup background services after apiserver tests
cleanup
PIDS=()  # Reset PIDs array
trap cleanup EXIT  # Reset trap

# Run tests for other crates
[[ -f "$TOOLS_MANIFEST" ]] && run_tests "$TOOLS_MANIFEST" "tools" || echo "::warning ::$TOOLS_MANIFEST not found, skipping..."
[[ -f "$AGENT_MANIFEST" ]] && run_tests "$AGENT_MANIFEST" "agent" || echo "::warning ::$AGENT_MANIFEST not found, skipping..."
# The following can be enabled if needed:
# [[ -f "$FILTERGATEWAY_MANIFEST" ]] && run_tests "$FILTERGATEWAY_MANIFEST" "filtergateway"
# [[ -f "$ACTIONCONTROLLER_MANIFEST" ]] && run_tests "$ACTIONCONTROLLER_MANIFEST" "actioncontroller"

# Combine all individual JUnit XML files into a single summary report
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "$REPORT_FILE"
echo "<testsuites>" >> "$REPORT_FILE"
for xml in dist/tests/*_results.xml; do
  [[ -f "$xml" ]] && cat "$xml" >> "$REPORT_FILE"
done
echo "</testsuites>" >> "$REPORT_FILE"

echo "✅ Tests Passed: $PASSED_TOTAL" | tee -a "$LOG_FILE"
echo "❌ Tests Failed: $FAILED_TOTAL" | tee -a "$LOG_FILE"

if [[ "$FAILED_TOTAL" -gt 0 ]]; then
  echo "::error ::Some tests failed!" | tee -a "$LOG_FILE"
  exit 1
fi

echo "🎉 All tests passed successfully!" | tee -a "$LOG_FILE"
