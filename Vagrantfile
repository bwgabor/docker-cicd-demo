# File: Vagrantfile
# Purpose: Create an Ubuntu 24.04 VM with Docker Engine + Compose plugin provisioning
# Save to: docker-cicd-demo/Vagrantfile
# Note: for local development/demo environment only

# Configuration for VM
Vagrant.configure("2") do |config|
  # Ubuntu 24.04 LTS box
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.hostname = "docker-cicd-demo"

  # Private network with static IP
  config.vm.network "private_network", ip: "192.168.56.10"

  # VirtualBox provider settings
  config.vm.provider "virtualbox" do |vb|
    vb.name = "docker-cicd-demo"
    vb.memory = 4096
    vb.cpus = 2
  end

  # Synced folder (host <-> guest)
  config.vm.synced_folder ".", "/vagrant", disabled: false

  # Provisioning: Installing Docker Engine + Compose plugin
  config.vm.provision "shell", inline: <<-SHELL
    set -e

    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update
    apt-get install -y mc apache2-utils docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    usermod -aG docker vagrant

    # Docker daemon insecure registry configuration for registry.local
    cat <<'EOF' | sudo tee /etc/docker/daemon.json
    {
      "insecure-registries": ["registry.local"]
    }
    EOF

    systemctl restart docker

    docker --version
    docker compose version
  SHELL
end