# This file is part of the Feeze scheduling analysis tool.
#
# This code is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License, version 3,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License, version 3,
# along with this program.  If not, see <http://www.gnu.org/licenses/>


# -----------------------------------------------------------------------
#
#  Copyright (c) 2025, Tokiwa Software GmbH, Germany
#
#  Source of Vagrantfile
#
#  Defines one virtual machine per entry in config/machines.yml
#
#
# -----------------------------------------------------------------------

require 'yaml'

# Machines are described in YAML
CFG_PATH = File.join(File.dirname(__FILE__), 'config', 'machines.yml')
raise "config not found: #{CFG_PATH}" unless File.exist?(CFG_PATH)
cfg = YAML.load_file(CFG_PATH)

# fail loudly on malformed YAML instead of building empty paths/URLs later
raise "top level must be a hash" unless cfg.is_a?(Hash)
raise "no 'machines' list" unless cfg['machines'].is_a?(Array)
cfg['machines'].each_with_index do |m, i|
  raise "machines[#{i}] must be a hash, got #{m.class}" unless m.is_a?(Hash)
  %w[name box family target].each { |k| raise "machines[#{i}]: missing '#{k}'" unless m[k] }
end

Vagrant.configure("2") do |config|
  config.vm.box_check_update = false

  cfg['machines'].each do |m|
    config.vm.define m['name'] do |node|
      node.vm.box      = m['box']
      node.vm.hostname = m['name']

      # Vagrant copies only the provisioning script into the VM,
      #so the files it installs have to be mounted separately.
      node.vm.synced_folder "scripts/files", "/tmp/feeze-files"

      # A desktop takes a while to come up on a loaded host.
      node.vm.boot_timeout = 600

      node.vm.provider "virtualbox" do |vb|
        vb.name   = m['name']

        vb.memory = m.fetch('memory', cfg['defaults']['memory'])
        vb.cpus   = m.fetch('cpus',   cfg['defaults']['cpus'])
        vb.gui    = m.fetch('gui',    cfg['defaults']['gui'])
         # 128 MB of VRAM; the default leaves the desktop stuck at 800x600.
        vb.customize ["modifyvm", :id, "--vram", "128"]
        vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
      end
      # One script per package manager; 'family' selects which.
      node.vm.provision "shell",
        path: "scripts/install-#{m['family']}.sh",
        env: {
          "FEEZE_VERSION" => cfg['release'].to_s,
          "FEEZE_TARGET"  => m['target'].to_s
        }
    end
  end
end
