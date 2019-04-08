# Cluster Deployment with Calico Network
![alt text](https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcS8ZSnq8vxxNXQ4uoAKCoKUYYXRogxoJULNmOcTmnSejB9Hm16GlQ "Kubernetes Logo")

## Content
* [Getting started](https://github.com/jklaiber/KubernetesClusterCoreOS/tree/master/ClusterDeploymentCalico#getting-started)
* [Create Deployment Script](https://github.com/jklaiber/KubernetesClusterCoreOS/tree/master/ClusterDeploymentCalico#create-deployment-script)
* [Master Deployment](https://github.com/jklaiber/KubernetesClusterCoreOS/tree/master/ClusterDeploymentCalico#master-deployment)
  * [Minimum Requirements](https://github.com/jklaiber/KubernetesClusterCoreOS/tree/master/ClusterDeploymentCalico#minimum-requirements)
  * [Initialize Master](https://github.com/jklaiber/KubernetesClusterCoreOS/tree/master/ClusterDeployment#initialize-master)
  * [Access to the Cluster](https://github.com/jklaiber/KubernetesClusterCoreOS/tree/master/ClusterDeploymentCalico#access-to-the-cluster)
  * [Calico Plugin](https://github.com/jklaiber/KubernetesClusterCoreOS/tree/master/ClusterDeployment_Calico#calico-network-plugin)
* [Worker Deployment](https://github.com/jklaiber/KubernetesClusterCoreOS/tree/master/ClusterDeploymentCalico#worker-deployment)
  * [Minimum Requirements](https://github.com/jklaiber/KubernetesClusterCoreOS/tree/master/ClusterDeploymentCalico#minimum-requirements-1)
  * [Initialize Worker](https://github.com/jklaiber/KubernetesClusterCoreOS/tree/master/ClusterDeploymentCalico#initialize-workers)
  * [Join Cluster](https://github.com/jklaiber/KubernetesClusterCoreOS/tree/master/ClusterDeploymentCalico#join-cluster)

## Getting started
Install `kubectl` on your machine
```
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

chmod +x ./kubectl

sudo mv ./kubectl /usr/local/bin/kubectl
```
## Create Deployment Script
Create and save the following script to your local machine `./install-k8s.sh`
```bash
#!/bin/bash

sudo su
echo "Initializing docker service ..."
systemctl enable docker && systemctl start docker
echo "Docker service initialized successfully."

echo "Installing CNI ..."
CNI_VERSION="v0.6.0"
mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz" | tar -C /opt/cni/bin -xz
echo "CNI installation complete."

echo "Installing kubeadm, kubelet & kubectl ..."
RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
mkdir -p /opt/bin
cd /opt/bin
curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/amd64/{kubeadm,kubelet,kubectl}
chmod +x {kubeadm,kubelet,kubectl}
echo "Kubeadm, kubelet & kubectl installation complete."

echo "Initializing kubelet service ..."
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${RELEASE}/build/debs/kubelet.service" | sed "s:/usr/bin:/opt/bin:g" > /etc/systemd/system/kubelet.service
mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${RELEASE}/build/debs/10-kubeadm.conf" | sed "s:/usr/bin:/opt/bin:g" > /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
systemctl enable kubelet && systemctl start kubelet
echo "Kubelet service initialized successfully."

echo "Updating PATH ..."
echo 'PATH="$PATH:/opt/bin"' > ~/.bashrc

echo "Fix Digital Oceans private ip for routing"
IFACE=eth1  # change to eth1 for DO's private network
DROPLET_IP_ADDRESS=$(ip addr show dev $IFACE | awk 'match($0,/inet (([0-9]|\.)+).* scope global/,a) { print a[1]; exit }')
echo $DROPLET_IP_ADDRESS  # check this, just in case

sed -i '2s/^/Environment="KUBELET_EXTRA_ARGS=--node-ip='$DROPLET_IP_ADDRESS'"\n/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
# echo "KUBELET_EXTRA_ARGS=--node-ip=$DROPLET_IP_ADDRESS  " > /etc/default/kubelet # Use etc/default/kubelet config file instead

systemctl daemon-reload
systemctl restart kubelet

echo "Setup Complete"
```

## Master Deployment
### Minimum Requirements
- Stable version of CoreOS
- 2GB Ram
- 2 vCPU (important!)

### Initialize Master
Replace the `MASTER_IP` with the public ip of the master machine
```
ssh core@$MASTER_IP "bash -s" < ./install-k8s.sh
```
Connect to the master machine
```
ssh core@$MASTER_IP
```
We use flannel network which our pods use to communicate.  
Run the following commands
```
sudo su
```
```
PUBLIC_IP=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1 | head -n 1)
```
```
kubeadm init --apiserver-advertise-address=$PUBLIC_IP --pod-network-cidr=192.168.0.0/16
```
**Important:** Copy the join command from the command line!

### Access to the Cluster
Connect your local kubectl to the master machine.    
On the master machine run the following commands
```
ssh core@$MASTER_IP
```
```
mkdir -p $HOME/.kube
```
```
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
```
```
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
On the local machine run the following commands
```
mkdir -p $HOME/.kube
```
```
scp core@$MASTER_IP:~/.kube/config $HOME/.kube/config
```
```
chown $(id -u):$(id -g) $HOME/.kube/config
```
Check if you can see your master
```
kubectl get nodes
```

#### Calico Network Plugin
We want that our pods can communicate with each other, so we have to install a pod network add-on
```
kubectl apply -f etcd-calico.yml
```
```
kubectl apply -f calico.yml
```
**Note:** Change the IP address from the etcd server!
## Worker Deployment
### Minimum Requirements
- Stable version of CoreOS
- 2GB Ram
- 1 vCPU  

### Initialize workers
Replace the `MASTER_IP` with the public ip of the worker machine
```
ssh core@$WORKER_IP "bash -s" < ./install-k8s.sh
```
### Join Cluster
*Additional:* When there are problems with the access-token generate a new one with the following command
```
ssh core@$MASTER_IP sudo kubeadm token create
```
Join the worker to the Cluster
```
ssh core@$WORKER_IP sudo [access token]
```
Check the nodes (you should see the master and the workers)
```
kubectl get nodes
```
