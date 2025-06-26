#!/bin/bash
set -euo pipefail

echo "🛠️ Updating package lists..."
apt-get update -y

echo "📦 Installing common packages..."
common_packages=(
  libdbus-1-dev
  git-all
  make
  gcc
  protobuf-compiler
  build-essential
  pkg-config
  curl
  libssl-dev
  nodejs
  npm
  cargo-clippy
)
DEBIAN_FRONTEND=noninteractive apt-get install -y "${common_packages[@]}"
echo "✅ Base packages installed successfully."

# Install etcd and etcdctl
echo "🔧 Installing etcd..."
ETCD_VER=v3.5.11
curl -L "https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz" -o etcd.tar.gz
tar xzvf etcd.tar.gz
cp etcd-${ETCD_VER}-linux-amd64/etcd /usr/local/bin/
cp etcd-${ETCD_VER}-linux-amd64/etcdctl /usr/local/bin/
chmod +x /usr/local/bin/etcd /usr/local/bin/etcdctl
rm -rf etcd.tar.gz etcd-${ETCD_VER}-linux-amd64
echo "✅ etcd and etcdctl installed."

# Start etcd directly
echo "🚀 Starting etcd directly..."
nohup etcd \
  --name s1 \
  --data-dir /tmp/etcd-data \
  --initial-advertise-peer-urls http://localhost:2380 \
  --listen-peer-urls http://127.0.0.1:2380 \
  --advertise-client-urls http://localhost:2379 \
  --listen-client-urls http://127.0.0.1:2379 > etcd.log 2>&1 &

ETCD_PID=$!
echo "🔍 etcd started with PID $ETCD_PID"

# Wait for etcd to become healthy
echo "⏳ Waiting for etcd to be ready..."
for i in {1..10}; do
  if etcdctl --endpoints=http://localhost:2379 endpoint health &>/dev/null; then
    echo "✅ etcd is healthy and ready."
    break
  else
    echo "Waiting for etcd to become healthy... ($i)"
    sleep 2
  fi
done

if ! etcdctl --endpoints=http://localhost:2379 endpoint health &>/dev/null; then
  echo "::error ::etcd did not become healthy in time!"
  cat etcd.log
  exit 1
fi
