Vagrant.configure("2") do |config|
  config.vm.box_check_update = false

  config.vm.define "ubuntu" do |node|
    node.vm.box      = "bento/ubuntu-24.04"
    node.vm.hostname = "ubuntu"


    node.vm.provider "virtualbox" do |vb|
      vb.name   = "ubuntu"
      vb.memory = 4096
      vb.cpus   = 2
      vb.gui = true
      vb.customize ["modifyvm", :id, "--vram", "128"]
      vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
    end

    node.vm.provision "shell", path: "scripts/install.sh"

  end
end
