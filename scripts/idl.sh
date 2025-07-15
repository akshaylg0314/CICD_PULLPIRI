#!/bin/bash
set -euo pipefail

echo "🛠️ Updating package lists..."
apt-get update -y

echo "📦 Installing Docker dependencies..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

echo "🔐 Adding Docker GPG key and repo..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Detect OS codename (e.g., jammy, focal)
UBUNTU_CODENAME=$(lsb_release -cs)

echo "📦 Adding Docker APT repo for $UBUNTU_CODENAME..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y

echo "🐳 Installing Docker Engine and Compose plugin..."
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo "✅ Docker Version:"
docker --version
echo "✅ Docker Compose Version:"
docker compose version

# ------------------------------------------------------
# Step 2: Clone and run the IDL2DDS repo via docker-compose
# ------------------------------------------------------

echo "📁 Cloning IDL2DDS repository..."
git clone https://github.com/MCO-PICCOLO/IDL2DDS -b master
cd IDL2DDS

echo "🐳 Building and starting IDL2DDS container..."
docker compose up -d --build