#!/bin/bash
# provision.sh – Docker Engine + Compose plugin installation for Ubuntu 24.04
# Idempotent: can be safely run multiple times

set -e
export DEBIAN_FRONTEND=noninteractive

# Install Docker (if not already installed)
if ! command -v docker &>/dev/null; then
  echo "[provision] Installing Docker..."

  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release mc apache2-utils

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

  systemctl enable docker
  systemctl start docker
  usermod -aG docker vagrant
  echo "[provision] Docker installed."
else
  echo "[provision] Docker already installed, skipping."
fi

# Insecure registry config (only if not already present)
if [ ! -f /etc/docker/daemon.json ]; then
  echo "[provision] Writing daemon.json..."
  cat <<'EOF' > /etc/docker/daemon.json
{
  "insecure-registries": ["registry.local"]
}
EOF
  systemctl restart docker
  echo "[provision] daemon.json written."
else
  echo "[provision] daemon.json already exists, skipping."
fi

# Version check
docker --version
docker compose version

# VM /etc/hosts append (registry.local)
if ! grep -q "registry.local" /etc/hosts; then
  echo "[provision] adding registry.local to /etc/hosts..."
  echo "127.0.0.1 registry.local" >> /etc/hosts
fi