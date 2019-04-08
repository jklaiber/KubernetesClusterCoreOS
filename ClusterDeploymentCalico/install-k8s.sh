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
