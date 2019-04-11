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
IFACE=eth1
DROPLET_IP_ADDRESS=$(ip addr show eth1 | grep -o 'inet [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | grep -o [0-9].*)
echo $DROPLET_IP_ADDRESS

echo "Create kubelet Environment file"
echo "KUBELET_EXTRA_ARGS=--node-ip=$DROPLET_IP_ADDRESS" > /etc/default/kubelet

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
We want that our pods can communicate with each other, so we have to install a pod network add-on.  

**Note:** The default network CIDR is `192.168.0.0/16`
```
kubectl apply -f https://docs.projectcalico.org/v3.5/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
```
**Important:** Check if the master is Ready after this deployment
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
## Dashboard Deployment
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml
```
### Create Dashboard Admin ClusterRole
Save this file as `k8s-admin-dashboard-user.yaml`
```yaml

apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
```
Run the command
```
kubectl apply -f ./k8s-admin-dashboard-user.yaml
```
### Access the dashboard
```
kubectl proxy
```
```
http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/
```
Generate an access token
```
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
```
Use this token to connect with the dashboard
