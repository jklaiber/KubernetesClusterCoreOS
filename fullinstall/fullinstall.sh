#!/bin/bash

banner()
{
  echo "+------------------------------------------+"
  printf "| %-40s |\n" "`date`"
  echo "|                                          |"
  printf "|`tput bold` %-40s `tput sgr0`|\n" "$@"
  echo "+------------------------------------------+"
}

banner "Starting the Job"
sleep 1

banner "Type in the IP Addresses"
echo "Master IP:"
read varmasterip
echo "Minion1 IP:"
read varminion1ip
echo "Minion2 IP:"
read varminion2ip
echo "Minion3 IP:"
read varminion3ip
sleep 1

banner "Check IP Addresses"
ping -c 3 $varmasterip
ping -c 3 $varminion1ip
ping -c 3 $varminion2ip
ping -c 3 $varminion3ip
sleep 1

banner "Install Kubernetes Deployment"
banner "Install Kubernetes Deployment - $varmasterip"
ssh core@$varmasterip "bash -s" < ./install-k8s.sh
banner "Install Kubernetes Deployment - $varminion1ip"
ssh core@$varminion1ip "bash -s" < ./install-k8s.sh
banner "Install Kubernetes Deployment - $varminion2ip"
ssh core@$varminion2ip "bash -s" < ./install-k8s.sh
banner "Install Kubernetes Deployment - $varminion3ip"
ssh core@$varminion3ip "bash -s" < ./install-k8s.sh
sleep 3

banner "Initialize Master"
ssh core@$varmasterip 'sudo kubeadm init --apiserver-advertise-address=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1 | head -n 1) --pod-network-cidr=192.168.0.0/16'

banner "Configure kubectl"
ssh core@$varmasterip 'mkdir -p $HOME/.kube'
ssh core@$varmasterip 'sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config'
ssh core@$varmasterip 'sudo chown $(id -u):$(id -g) $HOME/.kube/config'
mkdir -p $HOME/.kube
scp core@$varmasterip:~/.kube/config $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
echo "kubectl finished"

banner "Check Master & kubectl"
kubectl get nodes

banner "Installing Calico Network"
kubectl apply -f https://docs.projectcalico.org/v3.5/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml

banner "Join Nodes to Cluster"
jointoken=`ssh core@$varmasterip 'sudo kubeadm token create --print-join-command'`
echo $jointoken
ssh core@$varminion1ip sudo $jointoken
ssh core@$varminion2ip sudo $jointoken
ssh core@$varminion3ip sudo $jointoken

banner "Deploy Dashboard"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml
kubectl apply -f ./k8s-admin-dashboard-user.yaml

banner "Generate Access Token"
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')

banner "Finished."
