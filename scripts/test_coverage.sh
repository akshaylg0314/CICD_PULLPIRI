#!/bin/bash
set -euo pipefail

# === Initialize paths and variables ===
LOG_FILE="dist/coverage/test_coverage_log.txt"
COVERAGE_ROOT="dist/coverage"
mkdir -p "$COVERAGE_ROOT"
rm -f "$LOG_FILE"
touch "$LOG_FILE"
PIDS=()

echo "🧪 Starting test coverage collection per crate..." | tee -a "$LOG_FILE"

# === Function: Start background service ===
start_service() {
  local manifest="$1"
  local name="$2"
  echo "🔄 Starting $name..." | tee -a "$LOG_FILE"
  cargo run --manifest-path="$manifest" &>> "$LOG_FILE" &
  PIDS+=($!)
}

# === Function: Stop all background services ===
cleanup() {
  echo -e "\n🧹 Stopping services..." | tee -a "$LOG_FILE"
  for pid in "${PIDS[@]}"; do
    if kill -0 "$pid" &>/dev/null; then
      if ! kill "$pid" 2>/dev/null; then
        echo "⚠️ Could not kill PID $pid" | tee -a "$LOG_FILE"
      fi
    fi
  done
  PIDS=()
}

# === Ensure cargo-tarpaulin is installed ===
if ! command -v cargo-tarpaulin &>/dev/null; then
  echo "📦 Installing cargo-tarpaulin..." | tee -a "$LOG_FILE"
  cargo install cargo-tarpaulin
fi

# === Enable nightly-only options ===
export RUSTC_BOOTSTRAP=1

# === MANIFEST paths ===
COMMON_MANIFEST="src/common/Cargo.toml"
AGENT_MANIFEST="src/agent/Cargo.toml"
TOOLS_MANIFEST="src/tools/Cargo.toml"
APISERVER_MANIFEST="src/server/apiserver/Cargo.toml"
FILTERGATEWAY_MANIFEST="src/player/filtergateway/Cargo.toml"
ACTIONCONTROLLER_MANIFEST="src/player/actioncontroller/Cargo.toml"

# === COMMON ===
if [[ -f "$COMMON_MANIFEST" ]]; then
  echo "📂 Running tarpaulin for common" | tee -a "$LOG_FILE"
  mkdir -p "$COVERAGE_ROOT/common"
  (
    cd "$(dirname "$COMMON_MANIFEST")"
    cargo tarpaulin --out Html --out Lcov --out Xml \
      --output-dir "$COVERAGE_ROOT/common" \
      2>&1 | tee -a "$LOG_FILE" || true
  )
  mv "$COVERAGE_ROOT/common/tarpaulin-report.html" "$COVERAGE_ROOT/common/index.html" 2>/dev/null || true
else
  echo "::warning ::$COMMON_MANIFEST not found. Skipping..." | tee -a "$LOG_FILE"
fi

# === TOOLS ===
if [[ -f "$TOOLS_MANIFEST" ]]; then
  echo "📂 Running tarpaulin for tools" | tee -a "$LOG_FILE"
  mkdir -p "$COVERAGE_ROOT/tools"
  (
    cd "$(dirname "$TOOLS_MANIFEST")"
    cargo tarpaulin --out Html --out Lcov --out Xml \
      --output-dir "$COVERAGE_ROOT/tools" \
      2>&1 | tee -a "$LOG_FILE" || true
  )
  mv "$COVERAGE_ROOT/tools/tarpaulin-report.html" "$COVERAGE_ROOT/tools/index.html" 2>/dev/null || true
else
  echo "::warning ::$TOOLS_MANIFEST not found. Skipping..." | tee -a "$LOG_FILE"
fi

# === Step 2: Start `filtergateway` and `nodeagent` before apiserver ===
start_service "$FILTERGATEWAY_MANIFEST" "filtergateway"
start_service "$AGENT_MANIFEST" "nodeagent"
sleep 3

# === APISERVER ===
if [[ -f "$APISERVER_MANIFEST" ]]; then
  echo "📂 Running tarpaulin for apiserver" | tee -a "$LOG_FILE"
  mkdir -p "$COVERAGE_ROOT/apiserver"
  (
    cd "$(dirname "$APISERVER_MANIFEST")"
    cargo tarpaulin --out Html --out Lcov --out Xml \
      --output-dir "$COVERAGE_ROOT/apiserver" \
      2>&1 | tee -a "$LOG_FILE" || true
  )
  mv "$COVERAGE_ROOT/apiserver/tarpaulin-report.html" "$COVERAGE_ROOT/apiserver/index.html" 2>/dev/null || true
else
  echo "::warning ::$APISERVER_MANIFEST not found. Skipping..." | tee -a "$LOG_FILE"
fi

# Stop background services before next round
cleanup

# === Start IDL2DDS Docker Service ===
if ! docker ps | grep -qi "idl2dds"; then
  echo "📦 Launching IDL2DDS docker services..." | tee -a "$LOG_FILE"
  [[ ! -d IDL2DDS ]] && git clone https://github.com/MCO-PICCOLO/IDL2DDS -b master
  pushd IDL2DDS
  docker compose up --build -d
  popd
else
  echo "🟢 IDL2DDS already running." | tee -a "$LOG_FILE"
fi

# === ACTIONCONTROLLER and FILTERGATEWAY ===
start_service "$ACTIONCONTROLLER_MANIFEST" "actioncontroller"
sleep 3

if [[ -f "$FILTERGATEWAY_MANIFEST" ]]; then
  echo "📂 Running tarpaulin for filtergateway" | tee -a "$LOG_FILE"
  mkdir -p "$COVERAGE_ROOT/filtergateway"
  (
    cd "$(dirname "$FILTERGATEWAY_MANIFEST")"
    cargo tarpaulin --out Html --out Lcov --out Xml \
      --output-dir "$COVERAGE_ROOT/filtergateway" \
      2>&1 | tee -a "$LOG_FILE" || true
  )
  mv "$COVERAGE_ROOT/filtergateway/tarpaulin-report.html" "$COVERAGE_ROOT/filtergateway/index.html" 2>/dev/null || true
else
  echo "::warning ::$FILTERGATEWAY_MANIFEST not found. Skipping..." | tee -a "$LOG_FILE"
fi

cleanup

# === Summary ===
echo "✅ All test coverage reports generated at: $COVERAGE_ROOT" | tee -a "$LOG_FILE"
