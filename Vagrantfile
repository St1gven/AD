# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.define "dc1" do |node|
    node.vm.box = "centos/8"
    node.vm.box_version = "1905.1"
    node.vm.box_check_update = false
    
    node.vm.hostname = "dc1.st1gven.com"
    node.vm.network "private_network", ip: "172.25.0.1", netmask: "255.255.0.0", virtualbox__intnet: true
    
    node.vm.provision "shell", path: "dc.sh", env: {"PASSWORD" => "ZA1BASs"}
  end
  
  (1..2).each do |id|
    config.vm.define "node#{id}" do |node|
      node.vm.box = "centos/8"
      node.vm.box_version = "1905.1"
      node.vm.box_check_update = false
      
      node.vm.hostname = "node#{id}.st1gven.com"
      node.vm.network "private_network", type: "dhcp", virtualbox__intnet: true
      
      node.vm.provision "shell", path: "node.sh", env: {"PASSWORD" => "ZA1BASs"}
    end
  end

  (1..2).each do |id|
    config.vm.define "ws#{id}" do |node|
      node.vm.box = "gusztavvargadr/windows-10-enterprise"
      node.vm.box_version = "2004.0.2008"
      node.vm.box_check_update = false
      
      node.vm.hostname = "ws#{id}"
      node.vm.network "private_network", type: "dhcp", virtualbox__intnet: true
      
      node.vm.provision "shell", path: "ws.ps1", env: {"REALM" => "ST1GVEN.COM", "PASSWORD" => "ZA1BASs"}
    end
  end
  
  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.memory=1024
    vb.cpus=1
    vb.check_guest_additions=false
  end
end
