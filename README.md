# Create Kubernetes Cluster (on DigitalOcean) with CoreOS
![alt text](https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcS8ZSnq8vxxNXQ4uoAKCoKUYYXRogxoJULNmOcTmnSejB9Hm16GlQ "Kubernetes Logo")

## ToDo's
- [x] Initial Deployment
- [x] Nginx Ingress Deployment
- [x] Dashboard Deployment
- [ ] Reconfigure for baremetal Deployment
- [ ] Configure own loadbalancing service
- [ ] Make the dashboard public

## Content
* [Getting started](link)
* [Create Deployment Script](link)
* [Master Deployment](link)
  * [Minimum Requirements](link)
  * [Initialize Master](link)
  * [Access to the Cluster](link)
  * [Flannel Plugin](link)
* [Worker Deployment](link)
  * [Minimum Requirements](link)
  * [Initialize Worker](link)
  * [Join Cluster](link)
* [Loadbalancing Deployment](link)
  * [DigitalOcean Load Balancer](link)
  * [ToDo Bare Metal Load Balancer](link)
* [Dashboard Deployment](link)
  * [Create Dashboard Admin ClusterRole](link)
  * [Access the dashboard](link)

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

## Please note that this assumes KUBELET_EXTRA_ARGS hasn’t already been set in the unit file.
echo "Fix Digital Oceans private ip for routing"
IFACE=eth1  # change to eth1 for DO's private network
DROPLET_IP_ADDRESS=$(ip addr show dev $IFACE | awk 'match($0,/inet (([0-9]|\.)+).* scope global/,a) { print a[1]; exit }')
echo $DROPLET_IP_ADDRESS  # check this, just in case

## UPDATE
## If you are using kubernetes 1.11 and above, please note that adding KUBELET_EXTRA_ARGS on line 43 to 10-kubeadm.conf file
## wouldn't work any more.
## But adding the config to /etc/default/kubelet should solve the networking issue if you are experiencing it.

## Uncomment line 44 and comment out line 43 below if you are using kubernetes 1.11 and above.
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
kubeadm init --apiserver-advertise-address=$PUBLIC_IP  --pod-network-cidr=10.244.0.0/16
```
** Important: ** Copy the join command from the command line!

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

#### Flannel plugin
We want that our pods can communicate with each other, so we have to install a pod network add-on
```
ssh core@$MASTER_IP sudo sysctl net.bridge.bridge-nf-call-iptables=1
```
https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/
```
kubectl apply -f [link from kubernetes.io]
```
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
## Loadbalancing Deployment
With the nginx ingress controller, we can install the node-port service (needed for our external load balancer) as well as the need ingress directives for a baremetal kubernetes cluster. Run the following commands to install:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
```
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/baremetal/service-nodeport.yaml
```
Check if the ingress controller have started (`Ctrl+C` to stop)
```
kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx --watch
```
**Important:** When the flannel network is not started then the nodes will not get in the Ready status!
## ToDo Loadbalancing

## Dashboard Deployment
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml
```
When you want to display charts and graphs you will need to deploy charting tools.
```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: monitoring-influxdb
  namespace: kube-system
spec:
  replicas: 1
  template:
    metadata:
      labels:
        task: monitoring
        k8s-app: influxdb
    spec:
      containers:
      - name: influxdb
        image: k8s.gcr.io/heapster-influxdb-amd64:v1.3.3
        volumeMounts:
        - mountPath: /data
          name: influxdb-storage
      volumes:
      - name: influxdb-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  labels:
    task: monitoring
    # For use as a Cluster add-on (https://github.com/kubernetes/kubernetes/tree/master/cluster/addons)
    # If you are NOT using this as an addon, you should comment out this line.
    kubernetes.io/cluster-service: 'true'
    kubernetes.io/name: monitoring-influxdb
  name: monitoring-influxdb
  namespace: kube-system
spec:
  ports:
  - port: 8086
    targetPort: 8086
  selector:
    k8s-app: influxdb
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: heapster
  namespace: kube-system
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: heapster
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:heapster
subjects:
- kind: ServiceAccount
  name: heapster
  namespace: kube-system
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: heapster
  namespace: kube-system
spec:
  replicas: 1
  template:
    metadata:
      labels:
        task: monitoring
        k8s-app: heapster
    spec:
      serviceAccountName: heapster
      containers:
      - name: heapster
        image: k8s.gcr.io/heapster-amd64:v1.4.2
        imagePullPolicy: IfNotPresent
        command:
        - /heapster
        - --source=kubernetes:https://kubernetes.default
        - --sink=influxdb:http://monitoring-influxdb.kube-system.svc:8086
---
apiVersion: v1
kind: Service
metadata:
  labels:
    task: monitoring
    # For use as a Cluster add-on (https://github.com/kubernetes/kubernetes/tree/master/cluster/addons)
    # If you are NOT using this as an addon, you should comment out this line.
    kubernetes.io/cluster-service: 'true'
    kubernetes.io/name: Heapster
  name: heapster
  namespace: kube-system
spec:
  ports:
  - port: 80
    targetPort: 8082
  selector:
    k8s-app: heapster
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: monitoring-grafana
  namespace: kube-system
spec:
  replicas: 1
  template:
    metadata:
      labels:
        task: monitoring
        k8s-app: grafana
    spec:
      containers:
      - name: grafana
        image: k8s.gcr.io/heapster-grafana-amd64:v4.4.3
        ports:
        - containerPort: 3000
          protocol: TCP
        volumeMounts:
        - mountPath: /etc/ssl/certs
          name: ca-certificates
          readOnly: true
        - mountPath: /var
          name: grafana-storage
        env:
        - name: INFLUXDB_HOST
          value: monitoring-influxdb
        - name: GF_SERVER_HTTP_PORT
          value: "3000"
          # The following env variables are required to make Grafana accessible via
          # the kubernetes api-server proxy. On production clusters, we recommend
          # removing these env variables, setup auth for grafana, and expose the grafana
          # service using a LoadBalancer or a public IP.
        - name: GF_AUTH_BASIC_ENABLED
          value: "false"
        - name: GF_AUTH_ANONYMOUS_ENABLED
          value: "true"
        - name: GF_AUTH_ANONYMOUS_ORG_ROLE
          value: Admin
        - name: GF_SERVER_ROOT_URL
          # If you're only using the API Server proxy, set this value instead:
          # value: /api/v1/namespaces/kube-system/services/monitoring-grafana/proxy
          value: /
      volumes:
      - name: ca-certificates
        hostPath:
          path: /etc/ssl/certs
      - name: grafana-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  labels:
    # For use as a Cluster add-on (https://github.com/kubernetes/kubernetes/tree/master/cluster/addons)
    # If you are NOT using this as an addon, you should comment out this line.
    kubernetes.io/cluster-service: 'true'
    kubernetes.io/name: monitoring-grafana
  name: monitoring-grafana
  namespace: kube-system
spec:
  # In a production setup, we recommend accessing Grafana through an external Loadbalancer
  # or through a public IP.
  # type: LoadBalancer
  # You could also use NodePort to expose the service at a randomly-generated port
  # type: NodePort
  ports:
  - port: 80
    targetPort: 3000
  selector:
    k8s-app: grafana
```
Save this file as `heapster-influxdb-grafana.yaml` and run the commands
```
kubectl apply -f ./heapster-influxdb-grafana.yaml
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

