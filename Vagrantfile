# Vagrantfile
# Ubuntu 24.04 VM Docker Engine + Compose pluginnal

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.hostname = "docker-cicd-demo"


  # Fix IP a demo hálózatának
  config.vm.network "private_network", ip: "192.168.56.10"
  config.vm.provider "virtualbox" do |vb|
    vb.name = "docker-cicd-demo"
    vb.memory = 4096
    vb.cpus = 2
  end

  # Host mappa -> Guest mappa
  config.vm.synced_folder ".", "/vagrant", disabled: false

  # Kiszervezett, idempotens shell provisioner
  config.vm.provision "shell", path: "scripts/provision.sh"
end