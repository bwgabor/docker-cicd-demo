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
  "insecure-registries": [
    "registry.local",
    "registry:5001",
    "localhost:5001"
  ]
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

# Build custom Jenkins image (skip if already exists)
if ! docker image inspect custom-jenkins &>/dev/null; then
  echo "[provision] Building custom Jenkins image..."
  docker build -t custom-jenkins /vagrant/docker-files/jenkins
else
  echo "[provision] custom-jenkins image already exists, skipping."
fi

# Start the platform stack (skip if already running)
if [ -z "$(docker compose -f /vagrant/docker-compose.yml ps -q)" ]; then
  echo "[provision] Starting Docker Compose stack..."
  docker compose -f /vagrant/docker-compose.yml up -d
else
  echo "[provision] Stack already running, skipping."
fi

# Final status check
echo ""
echo "[provision] Stack status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Set up demo app directory in vagrant home
if [ ! -d "/home/vagrant/nginx-static-site" ]; then
  echo "[provision] Setting up demo app files..."
  mkdir -p /home/vagrant/nginx-static-site
  cp /vagrant/demo/nginx-static-site/Dockerfile /home/vagrant/nginx-static-site/
  cp /vagrant/demo/nginx-static-site/Jenkinsfile /home/vagrant/nginx-static-site/
  cp /vagrant/demo/nginx-static-site/index.html /home/vagrant/nginx-static-site/
  chown -R vagrant:vagrant /home/vagrant/nginx-static-site
else
  echo "[provision] Demo app directory already exists, skipping."
fi