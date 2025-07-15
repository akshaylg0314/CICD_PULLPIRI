#!/bin/bash
set -euxo pipefail

export RUSTC_BOOTSTRAP=1
LOG_FILE="test_results.log"

echo "🛠️ Updating package lists..."
apt-get update -y

echo "📦 Installing common development packages..."
apt-get install -y \
  libdbus-1-dev \
  git-all \
  make \
  gcc \
  protobuf-compiler \
  build-essential \
  pkg-config \
  curl \
  libssl-dev \
  nodejs \
  ca-certificates \
  gnupg \
  lsb-release \
  unzip \
  jq \
  software-properties-common

echo "✅ Base packages installed."

# 🦀 Rust Setup
if ! command -v rustup &>/dev/null; then
  echo "🦀 Installing rustup..."
  curl https://sh.rustup.rs -sSf | sh -s -- -y
  source "$HOME/.cargo/env"
fi

export PATH="$HOME/.cargo/bin:$PATH"

rustup component add clippy
rustup component add rustfmt

if ! command -v cargo-deny &>/dev/null; then
  cargo install cargo-deny
fi

if ! command -v cargo2junit &>/dev/null; then
  cargo install cargo2junit
fi

echo "📌 Installed:"
cargo --version
cargo fmt --version
cargo clippy --version
cargo deny --version

# etcd
echo "🔧 Installing etcd..."
ETCD_VER="v3.5.11"
ETCD_PKG="etcd-${ETCD_VER}-linux-amd64"
curl -L "https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/${ETCD_PKG}.tar.gz" -o etcd.tar.gz
tar xzvf etcd.tar.gz
cp "${ETCD_PKG}/etcd" /usr/local/bin/
cp "${ETCD_PKG}/etcdctl" /usr/local/bin/
chmod +x /usr/local/bin/etcd /usr/local/bin/etcdctl
rm -rf etcd.tar.gz "${ETCD_PKG}"

echo "🚀 Starting etcd..."
nohup etcd \
  --name s1 \
  --data-dir /tmp/etcd-data \
  --initial-advertise-peer-urls http://localhost:2380 \
  --listen-peer-urls http://127.0.0.1:2380 \
  --advertise-client-urls http://localhost:2379 \
  --listen-client-urls http://127.0.0.1:2379 > etcd.log 2>&1 &

ETCD_PID=$!
for i in {1..10}; do
  if etcdctl --endpoints=http://localhost:2379 endpoint health &>/dev/null; then
    echo "✅ etcd is healthy"
    break
  else
    echo "⌛ Waiting for etcd to be healthy... ($i)"
    sleep 2
  fi
done

if ! etcdctl --endpoints=http://localhost:2379 endpoint health &>/dev/null; then
  echo "::error ::etcd did not become healthy in time!"
  cat etcd.log
  exit 1
fi

# 🐳 Docker
echo "🐳 Installing Docker..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu jammy stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
docker --version
docker compose version

echo "✅ Docker installed."

# === Docker Service: IDL2DDS ===
if ! docker ps | grep -qi "idl2dds"; then
  echo "📦 Launching IDL2DDS..."

  [[ ! -d IDL2DDS ]] && git clone https://github.com/MCO-PICCOLO/IDL2DDS -b master

  pushd IDL2DDS

  # Create a minimal config if needed
  if [[ ! -f cyclonedds.xml ]]; then
    echo '<CycloneDDS><Domain><Id>0</Id></Domain></CycloneDDS>' > cyclonedds.xml
  fi

  # Fix mount point: DO NOT mount to an existing directory path
  # Use a safe file location instead
  cat <<EOF > docker-compose.override.yml
services:
  dds-sender:
    volumes:
      - ./cyclonedds.xml:/app/cyclonedds-config.xml
    environment:
      CYCLONEDDS_URI: /app/cyclonedds-config.xml
EOF

  docker compose down -v || true  # Clean up previous volumes if any
  docker compose up -d --build | tee -a "../$LOG_FILE"
  docker compose ps
  popd
else
  echo "🟢 IDL2DDS already running." | tee -a "$LOG_FILE"
fi

echo "🎉 All setup complete. etcd and DDS services are up."
