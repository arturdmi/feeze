require 'yaml'

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

      node.vm.provider "virtualbox" do |vb|
        vb.name   = m['name']
        vb.memory = m.fetch('memory', cfg['defaults']['memory'])
        vb.cpus   = m.fetch('cpus',   cfg['defaults']['cpus'])
        vb.gui    = m.fetch('gui',    cfg['defaults']['gui'])
        vb.customize ["modifyvm", :id, "--vram", "128"]
        vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
      end
      unless m['family'] == 'none'
      node.vm.provision "shell",
        path: "scripts/install-#{m['family']}.sh",
        env: {
          "FEEZE_VERSION" => cfg['release'].to_s,
          "FEEZE_TARGET"  => m['target'].to_s
        }
      end
    end
  end
end
