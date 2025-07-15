#!/bin/bash
set -euo pipefail

LOG_FILE="test_results.log"
TMP_FILE="test_output.txt"
REPORT_FILE="dist/tests/test_summary.xml"

# Ensure dist/tests and target directories exist and are writable
sudo mkdir -p dist/tests target
sudo chown -R "$(whoami)" dist target

# Clean old logs and report
rm -f "$LOG_FILE" "$TMP_FILE" "$REPORT_FILE"

echo "🚀 Running Cargo Tests..." | tee -a "$LOG_FILE"

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

start_service() {
  local manifest="$1"
  local name="$2"
  echo "🔄 Starting $name..." | tee -a "$LOG_FILE"
  sudo cargo run --manifest-path="$manifest" &>> "$LOG_FILE" &
  PIDS+=($!)
}

cleanup() {
  echo -e "\n🧹 Stopping services..." | tee -a "$LOG_FILE"
  for pid in "${PIDS[@]}"; do
    if sudo kill -0 "$pid" &>/dev/null; then
      sudo kill "$pid" 2>/dev/null || echo "⚠️ Could not kill $pid"
    fi
  done
  PIDS=()
}
trap cleanup EXIT

run_tests() {
  local manifest="$1"
  local label="$2"
  local output_json="target/${label}_test_output.json"
  local report_xml="dist/tests/${label}_results.xml"

  echo "🧪 Testing $label ($manifest)" | tee -a "$LOG_FILE"

  if sudo RUSTC_BOOTSTRAP=1 cargo test --manifest-path="$manifest" -- -Z unstable-options --format json \
      | sudo tee "$output_json" > /dev/null; then
    echo "✅ Tests completed for $label" | tee -a "$LOG_FILE"
  else
    echo "::error ::❌ Tests failed for $label (cargo test exited non-zero)!" | tee -a "$LOG_FILE"
  fi

  if [[ ! -f "$output_json" ]]; then
    echo "::error ::Output JSON $output_json not found, skipping parsing for $label"
    return
  fi

  if ! command -v jq &>/dev/null; then
    echo "::warning ::jq not found, skipping detailed test output"
  else
    echo "🔎 Test results for $label:" | tee -a "$LOG_FILE"
    jq -c 'select(.type=="test")' "$output_json" | while read -r line; do
      name=$(echo "$line" | jq -r '.name // "unknown"')
      event=$(echo "$line" | jq -r '.event // "unknown"')
      case "$event" in
        ok) status_symbol="✅" ;;
        failed) status_symbol="❌" ;;
        ignored) status_symbol="⚪" ;;
        *) status_symbol="❓" ;;
      esac
      echo "  $status_symbol $name ($event)" | tee -a "$LOG_FILE"
    done
  fi

  passed=$(jq -c 'select(.type=="test" and .event=="ok")' "$output_json" | wc -l || echo 0)
  failed=$(jq -c 'select(.type=="test" and .event=="failed")' "$output_json" | wc -l || echo 0)

  PASSED_TOTAL=$((PASSED_TOTAL + passed))
  FAILED_TOTAL=$((FAILED_TOTAL + failed))

  echo "ℹ️ Passed: $passed, Failed: $failed" | tee -a "$LOG_FILE"

  if [[ "$failed" -gt 0 ]]; then
    echo "::error ::❌ Tests failed for $label!" | tee -a "$LOG_FILE"
  fi

  if command -v cargo2junit &>/dev/null; then
    sudo cargo2junit < "$output_json" > "$report_xml"
  else
    echo "::warning ::cargo2junit not found, skipping XML for $label"
  fi
}

# === Step 1: common ===
[[ -f "$COMMON_MANIFEST" ]] && run_tests "$COMMON_MANIFEST" "common" || echo "::warning ::$COMMON_MANIFEST missing."

# === Step 2: apiserver + dependencies ===
[[ -f "$FILTERGATEWAY_MANIFEST" ]] && start_service "$FILTERGATEWAY_MANIFEST" "filtergateway"
[[ -f "$AGENT_MANIFEST" ]] && start_service "$AGENT_MANIFEST" "nodeagent"
sudo etcdctl del "" --prefix
sleep 3
[[ -f "$APISERVER_MANIFEST" ]] && run_tests "$APISERVER_MANIFEST" "apiserver" || echo "::warning ::$APISERVER_MANIFEST missing."
cleanup

# === Step 3: tools and agent ===
[[ -f "$TOOLS_MANIFEST" ]] && run_tests "$TOOLS_MANIFEST" "tools" || echo "::warning ::$TOOLS_MANIFEST missing."
[[ -f "$AGENT_MANIFEST" ]] && run_tests "$AGENT_MANIFEST" "agent" || echo "::warning ::$AGENT_MANIFEST missing."

# === Step 4: IDL2DDS (external container) ===
echo "📁 Cloning IDL2DDS repository..."
sudo git clone https://github.com/MCO-PICCOLO/IDL2DDS -b master
cd IDL2DDS

echo "🐳 Building and starting IDL2DDS container..."
sudo docker compose up -d --build

cd "$PROJECT_ROOT"

# === Step 5: filtergateway (with actioncontroller) ===
[[ -f "$ACTIONCONTROLLER_MANIFEST" ]] && start_service "$ACTIONCONTROLLER_MANIFEST" "actioncontroller"
sleep 3
[[ -f "$FILTERGATEWAY_MANIFEST" ]] && run_tests "$FILTERGATEWAY_MANIFEST" "filtergateway" || echo "::warning ::$FILTERGATEWAY_MANIFEST missing."
cleanup

# === Combine XML reports ===
if ls dist/tests/*_results.xml &>/dev/null; then
  echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "$REPORT_FILE"
  echo "<testsuites>" >> "$REPORT_FILE"
  cat dist/tests/*_results.xml >> "$REPORT_FILE"
  echo "</testsuites>" >> "$REPORT_FILE"
else
  echo "::warning ::No individual test XML files found; skipping report generation"
fi

# === Final results ===
echo "✅ Tests Passed: $PASSED_TOTAL" | tee -a "$LOG_FILE"
echo "❌ Tests Failed: $FAILED_TOTAL" | tee -a "$LOG_FILE"

if [[ "$FAILED_TOTAL" -gt 0 ]]; then
  echo "::error ::Some tests failed!" | tee -a "$LOG_FILE"
  exit 1
fi

echo "🎉 All tests passed!" | tee -a "$LOG_FILE"
