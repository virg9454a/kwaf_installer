#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

clear

workingdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cat <<- EOF
==================================================================================
                               ___  ___ _      _____  
                              / _ \/ _ \ | /| / / _ \  
                             / , _/ // / |/ |/ / , _/  
                            /_/|_/____/|__/|__/_/|_|___
                              / //_/ | /| / / _ | / __/
                             / ,<  | |/ |/ / __ |/ _/  
                            /_/|_| |__/|__/_/ |_/_/    

==================================================================================
                               ! WARNING ACHTUNG !

This script will modify significantly this machine's configuration. 
Run on (a) dedicated CentOS 7 machine(s) !

==================================================================================
                             🎁 What's in the box 🎁

- a declarative and idempotent installer
- a Kubernetes 1.19 cluster ⎈ (1 or 3 nodes)
- helm 3 (no need for tiller)
- A private docker registry 🐳
- JuiceBox (a sample insecure application)
- Radware Kwaf

==================================================================================
Writen and maintained by Charles Durocher : charles.durocher@radware.com
==================================================================================

EOF

read -p "continue ? Ctrl+c to abort"

echo "Wunderbar ! ... Setting up installer requirements"
yum -y install epel-release
yum repolist
yum -y install ansible git vim

ansible-galaxy collection install community.kubernetes community.general

git clone https://github.com/kubernetes-sigs/kubespray $workingdir/../kubespray

read -p "please set the variables for your deployment, an editor will now be launched. continue ?"

"${EDITOR:-vim}" $workingdir/vars/k8s.yaml


echo "Begining installation of cluster prequisites"
read -p "You will be prompted for the local SSH password. continue ?"
ansible-playbook -i,127.0.0.1  $workingdir/prequisites.yml -u root -k

echo "⎈ Begining cluster deployment ⎈ (~20min)"
PS3='Please select wether you want to deploy using an SSH password or Key: '
options=("Password" "Key" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Password")
            echo "Installing using SSH password"
            ansible-playbook -i $workingdir/../kubespray/inventory/kwaf.ini $workingdir/../kubespray/cluster.yml -b -v -k
            ;;
        "Key")
            echo "Installing using SSH Key from ~/.ssh/id_rsa"
            ansible-playbook -i $workingdir/../kubespray/inventory/kwaf.ini $workingdir/../kubespray/cluster.yml -b -v --private-key=~/.ssh/id_rsa
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

echo "Getting OWASP Juice-Shop"
git clone https://github.com/bkimminich/juice-shop.git $workingdir/../juice-shop

echo "Begining Application deployment "
read -p "You will be prompted for the local SSH password. continue ?"
ansible-playbook -i,127.0.0.1  $workingdir/deployment.yml -u root -k

alias k="kubectl"
