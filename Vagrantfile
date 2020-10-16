# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  #config.vbguest.no_install = true
  config.vm.define "dc1" do |node|
    node.vm.box = "centos/8"
    node.vm.box_version = "1905.1"
    node.vm.box_check_update = false
    
    node.vm.hostname = "dc1.st1gven.com"
    node.vm.network "private_network", ip: "172.25.0.2", netmask: "255.255.255.0", virtualbox__intnet: "net1"
    node.vm.provision "shell", run: "always", inline: "ip route add default via 172.25.0.1 dev eth1"
    
    node.vm.provision "shell", path: "dc1.sh", env: {"PASSWORD" => "ZA1BASs"}
    
    #to compile samba vagrant plugin install vagrant-vbguest
    #node.vm.synced_folder "compile", "/vagrant/compile", create: true
    #node.vbguest.installer_options = { allow_kernel_upgrade: true }
    #node.vbguest.no_install = false
  end
  
  config.vm.define "dc2" do |node|
    node.vm.box = "centos/8"
    node.vm.box_version = "1905.1"
    node.vm.box_check_update = false
    
    node.vm.hostname = "dc2.st1gven.com"
    node.vm.network "private_network", ip: "172.25.0.3", netmask: "255.255.255.0", virtualbox__intnet: "net1"
    node.vm.provision "shell", run: "always", inline: "ip route add default via 172.25.0.1 dev eth1"
    
    node.vm.provision "shell", path: "dc2.sh", env: {"PASSWORD" => "ZA1BASs"}
  end
  
    config.vm.define "dc3" do |node|
    node.vm.box = "centos/8"
    node.vm.box_version = "1905.1"
    node.vm.box_check_update = false
    
    node.vm.hostname = "dc3.st1gven.com"
    node.vm.network "private_network", ip: "172.25.1.2", netmask: "255.255.255.0", virtualbox__intnet: "net3"
    
    node.vm.provision "shell", run: "always", inline: "ip route add default via 172.25.1.1 dev eth1"
    node.vm.provision "shell", path: "dc2.sh", env: {"PASSWORD" => "ZA1BASs", "SITE" => "testSite"}
  end
  
  (1..2).each do |id|
    config.vm.define "node#{id}" do |node|
      node.vm.box = "centos/8"
      node.vm.box_version = "1905.1"
      node.vm.box_check_update = false
      
      node.vm.hostname = "node#{id}.st1gven.com"
      node.vm.network "private_network", type: "dhcp", virtualbox__intnet: "net1"
      
      node.vm.provision "shell", path: "node.sh", env: {"PASSWORD" => "ZA1BASs"}
    end
  end

  (1..2).each do |id|
    config.vm.define "ws#{id}" do |node|
      node.vm.box = "gusztavvargadr/windows-10-enterprise"
      node.vm.box_version = "2004.0.2008"
      node.vm.box_check_update = false
      
      node.vm.hostname = "ws#{id}"
      node.vm.network "private_network", type: "dhcp", virtualbox__intnet: "net1"
      
      node.vm.provision "shell", path: "ws.ps1", env: {"REALM" => "ST1GVEN.COM", "PASSWORD" => "ZA1BASs"}
      
      node.vm.provider "virtualbox" do |vb|
        vb.memory = 2048
        vb.cpus = 2
        vb.customize ["modifyvm", :id, "--vram", "128"]
      end;
    end
  end
  
  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.memory = 1024
    vb.cpus = 1
    vb.check_guest_additions = false
  end
  
  
  config.vm.define "router1" do |node|
    node.vm.box = "generic/alpine312"
    node.vm.box_version = "3.0.34"
    
    node.vm.hostname = "router1.st1gven.com"
    node.vm.network "private_network", ip: "172.25.0.1", netmask: "255.255.255.0", virtualbox__intnet: "net1"
    node.vm.network "private_network", ip: "10.6.0.1", netmask: "255.255.255.252", virtualbox__intnet: "net2"
    
    node.vm.provision "shell", inline: "apk add iptables"
    node.vm.provision "shell", inline: "echo 1 > /proc/sys/net/ipv4/ip_forward"
    
    node.vm.provision "shell", run: "always", inline: "ip route add 172.25.1.0/24 via 10.6.0.2 dev eth2"
    node.vm.provision "shell", run: "always", inline: "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE && iptables -A FORWARD -i eth1 -j ACCEPT"
    
    
    node.vm.provider "virtualbox" do |vb|
        vb.memory = 128
        vb.cpus = 1
    end;
  end
  
  config.vm.define "router2" do |node|
    node.vm.box = "generic/alpine312"
    node.vm.box_version = "3.0.34"
    
    node.vm.hostname = "router2.st1gven.com"
    node.vm.network "private_network", ip: "10.6.0.2", netmask: "255.255.255.252", virtualbox__intnet: "net2"
    node.vm.network "private_network", ip: "172.25.1.1", netmask: "255.255.255.0", virtualbox__intnet: "net3"
    
    node.vm.provision "shell", inline: "apk add iptables"
    node.vm.provision "shell", inline: "echo 1 > /proc/sys/net/ipv4/ip_forward"
    
    node.vm.provision "shell", run: "always", inline: "ip route add 172.25.0.0/24 via 10.6.0.1 dev eth1"
    node.vm.provision "shell", run: "always", inline: "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE && iptables -A FORWARD -i eth2 -j ACCEPT"
    
    node.vm.provider "virtualbox" do |vb|
        vb.memory = 128
        vb.cpus = 1
    end;
  end
  
  config.vm.define "test1" do |node|
    node.vm.box = "generic/alpine312"
    node.vm.box_version = "3.0.34"
    
    node.vm.hostname = "test1.st1gven.com"
    node.vm.network "private_network", ip: "172.25.1.5", netmask: "255.255.255.0", virtualbox__intnet: "net3"
    node.vm.provision "shell", run: "always", inline: "ip route add default via 172.25.1.1 dev eth1"
    
    node.vm.provider "virtualbox" do |vb|
        vb.memory = 128
        vb.cpus = 1
    end;
  end
end
