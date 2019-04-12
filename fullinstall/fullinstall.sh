#!/bin/bash

banner()
{
  echo "+------------------------------------------+"
  printf "| %-40s |\n" "`date`"
  echo "|                                          |"
  printf "|`tput bold` %-40s `tput sgr0`|\n" "$@"
  echo "+------------------------------------------+"
}

# Array
declare -a minion_ips

banner "Starting the Job"
sleep 1

banner "Type in the IP Addresses"
read -p "Master IP: " varmasterip
read -p "Amount of Minions: " minion_amount
for (( i=1; i<=$minion_amount; i++ ))
do
   read -p "Set Minion $i ip address: " temp_ip
   minion_ips[$i]=$temp_ip
done
sleep 1

banner "Check IP Addresses"
ping -c 3 $varmasterip
for j in "${minion_ips[@]}"
do
  ((count = 10))                            # Maximum number to try.
  while [[ $count -ne 0 ]] ; do
      ping -c 1 $j                      # Try once.
      rc=$?
      if [[ $rc -eq 0 ]] ; then
          ((count = 1))                      # If okay, flag to exit loop.
      fi
      ((count = count - 1))                  # So we don't go forever.
  done

  if [[ $rc -eq 0 ]] ; then                  # Make final determination.
      echo `say Host is Reachable.`
  else
      echo `say Timeout.`
  fi
done
sleep 1

banner "Install Kubernetes Deployment"
banner "Install Kubernetes Deployment - $varmasterip"
ssh core@$varmasterip "bash -s" < ./install-k8s.sh
for y in "${minion_ips[@]}"
do
	banner "Install Kubernetes Deployment - $y"
  ssh core@$y "bash -s" < ./install-k8s.sh
done
sleep 1

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
ssh core@$varmasterip 'kubectl get nodes'

banner "Installing Calico Network"
ssh core@$varmasterip 'kubectl apply -f https://docs.projectcalico.org/v3.5/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml'

banner "Join Nodes to Cluster"
jointoken=`ssh core@$varmasterip 'sudo kubeadm token create --print-join-command'`
echo $jointoken

for z in "${minion_ips[@]}"
do
	ssh core@$z sudo $jointoken
done

banner "Deploy Dashboard"
ssh core@$varmasterip 'kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml'
ssh core@$varmasterip 'kubectl apply -f ./k8s-admin-dashboard-user.yaml'

banner "Generate Access Token"
ssh core@$varmasterip 'kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')'

banner "Finished."
