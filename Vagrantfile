# -*- mode: ruby -*-
# vi: set ft=ruby :

#Colors
# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

# master config
MASTER_NODE_NAME = 'pvivianS'
MASTER_NODE_IP = '192.168.42.110'

# common config
MEM = 2048
CPU = 2
BOX = "centos/8"
BOX_URL = "https://app.vagrantup.com/centos/boxes/8/versions/2011.0/providers/virtualbox.box"
BOX_AUTO_UPDATE = false

Vagrant.configure("2") do |config|

	config.vm.provision "shell", reboot: true, privileged: true, inline: <<-SHELL
	    echo -e "\03Loading and updating OS\033[0m\n"
		sudo sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
		sudo sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
		sudo yum update -y
	    yum install net-tools -y
	SHELL

	config.vm.box = BOX
	config.vm.box_url = BOX_URL
	config.vm.box_check_update = BOX_AUTO_UPDATE

	config.vm.provider "virtualbox" do |v|
		v.memory = MEM
		v.cpus = CPU
	end

	config.vm.define MASTER_NODE_NAME do |master|
		master.vm.hostname = MASTER_NODE_NAME
		master.vm.network :private_network, ip: MASTER_NODE_IP
		master.vm.provider "virtualbox" do |v|
			v.name = MASTER_NODE_NAME
			# v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/vagrant", "1"]
		end
		config.vm.provision "shell", reboot: true, privileged: true, inline: <<-SHELL
            echo -e "\033[1;33mLoading k3d\033[0m\n"
            curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

            echo -e "\033[1;33mLoading docker\033[0m\n"
            sudo yum install -y yum-utils device-mapper-persistent-data lvm2
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

            echo -e "\033[1;33mLoading kubectl\033[0m\n"
            sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            sudo chmod +x /usr/local/bin/kubectl

            echo -e "\033[1;33mLoading argocd\033[0m\n"
            sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
            sudo chmod +x /usr/local/bin/argocd
        SHELL

        config.vm.provision "shell", privileged: true, inline: <<-SHELL
            echo -e "\033[1;33mStart docker\033[0m\n"
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
            newgrp docker

            echo -e "\033[1;33mCreate cluster\033[0m\n"
            k3d cluster create mycluster

            echo -e "\033[1;33mSetup argocd\033[0m\n"
            kubectl create namespace argocd
            kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

            kubectl apply -f /vagrant/confs/ingress.yaml -n argocd

            kubectl -n argocd patch secret argocd-secret \
              -p '{"stringData": {
                "admin.password": "$2y$12$Kg4H0rLL/RVrWUVhj6ykeO3Ei/YqbGaqp.jAtzzUSJdYWT6LUh/n6",
                "admin.passwordMtime": "'$(date +%FT%T%Z)'"
              }}'

            kubectl create namespace dev
            kubectl apply -f /vagrant/confs/project.yaml -n argocd
            kubectl apply -f /vagrant/confs/application.yaml -n argocd

        SHELL
	end
end