#!/bin/bash

echo -e "\033[1;33mLoading and updating OS\033[0m\n"
sudo sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sudo sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
sudo yum update -y
yum install net-tools -y
export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin"
swapoff -a

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

echo -e "\033[1;33mStart docker\033[0m\n"
sudo usermod -aG docker vagrant
newgrp docker
sudo systemctl start docker
sudo systemctl enable docker

echo -e "\033[1;33mCreate cluster\033[0m\n"
k3d cluster create iotcluster
k3d kubeconfig merge iotcluster --kubeconfig-merge-default

echo -e "\033[1;33mSetup argocd\033[0m\n"
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2a$12$UCVHENi56FC3x2div0FC1.EJkw.QHxNq4aHTTeYB8Lxks9XiDYXDS",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'

kubectl create namespace dev
kubectl apply -f /vagrant/confs/project.yaml -n argocd
kubectl apply -f /vagrant/confs/application.yaml -n argocd
