echo -e "\033[1;33mLoading and updating OS\033[0m\n"
apt update -y && apt install -y jq
export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin"

echo -e "\033[1;33mLoading docker\033[0m\n"
nslookup get docker.com
curl -fsSL https://get.docker.com | bash
usermod -aG docker $USER

echo -e "\033[1;33mLoading k3d\033[0m\n"
curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash

echo -e "\033[1;33mLoading argocd\033[0m\n"
curl -fsSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

echo -e "\033[1;33mLoading kubectl\033[0m\n"
sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
sudo chmod +x /usr/local/bin/kubectl

echo -e "\033[1;33mCreating cluster\033[0m\n"
k3d cluster create gitlab
k3d kubeconfig merge gitlab --kubeconfig-merge-default

echo -e "\033[1;33mLaunching argocd\033[0m\n"
sudo kubectl create namespace gitlab
sudo kubectl create namespace argocd
sudo kubectl create namespace dev
sudo kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
sudo kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo -e "\033[1;33mLoading cluster\033[0m\n"
export GITLAB_HOME=$HOME/gitlab/

sudo docker run --detach \
  --hostname gitlab.odhazzar.com \
  --publish 443:443 --publish 80:80 --publish 2222:22 \
  --name gitlab \
  --restart always \
  --volume $GITLAB_HOME/config:/etc/gitlab \
  --volume $GITLAB_HOME/logs:/var/log/gitlab \
  --volume $GITLAB_HOME/data:/var/opt/gitlab \
  -e GITLAB_SKIP_UNMIGRATED_DATA_CHECK=true \
  --cpus 3 \
  gitlab/gitlab-ee:latest

bash -c 'while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:80)" != "302" ]]; do sleep 5; done'
sleep 60

echo -e "\033[1;33mConfiguring gitlab\033[0m\n"
docker exec gitlab gitlab-rails runner "token = User.find_by_username('root').personal_access_tokens.create(scopes: [:read_user, :read_repository, :api, :read_api, :write_repository, :sudo], name: 'Root token'); token.set_token('token-string-here123'); token.save!"
sleep 20

curl --header "Authorization: Bearer token-string-here123" --request POST "http://localhost/api/v4/projects?name=pvivian&visibility=public"
sleep 20

curl -v --request POST --header "Authorization: Bearer token-string-here123" \
--header "Content-type: application/json" \
--data "$(jq -n --arg content "$(curl https://raw.githubusercontent.com/kgornostaeva/pvivian/master/p3/confs/deployment.yaml)" \
        '{"branch": "master", "author_email": "root@example.com", "author_name": "Root", "content": $content, "commit_message": "Initial commit"}')" \
"http://localhost/api/v4/projects/2/repository/files/deployment%2Eyaml"

echo -e "\033[1;33mConfiguring argocd\033[0m\n"
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2a$12$UCVHENi56FC3x2div0FC1.EJkw.QHxNq4aHTTeYB8Lxks9XiDYXDS",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'

export ADDRESS="$(netstat -rn | grep "^0.0.0.0 " | cut -d " " -f10)"
sed -i "s/address/$ADDRESS/g" /vagrant/confs/project.yaml
kubectl apply -f /vagrant/confs/project.yaml -n argocd

echo -e "\033[1;33mDone!\nUse following command to get a gitlab initial password\nsudo docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password\033[0m\n"
