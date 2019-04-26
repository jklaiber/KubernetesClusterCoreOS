# Fullinstallation Script
The following Script will deploy a working Kubernetes Cluster.

## Requirements
* **One** Master Node (**CoreOS**)
* **One** or **more** Minion Nodes (**CoreOS**)
* All Nodes must be accessible with **SSH**
* You must know the Public **IP** Addresses (or Internal)

## Getting Started
Simply Clone this repo and navigate into the fullinstall folder
```
[user@localhost]$ git clone git@github.com:jklaiber/KubernetesClusterCoreOS.git
[user@localhost]$ cd fullinstall
```
Make the Script executable and run it
```
[user@localhost]$ chmod +x fullinstall.sh
[user@localhost]$ ./fullinstall.sh
```
## Example
```
[user@localhost]$ ./fullinstall.sh
+------------------------------------------+
| Fr Apr 26 13:38:54 CEST 2019             |
|                                          |
| Starting the Job                         |
+------------------------------------------+
+------------------------------------------+
| Fr Apr 26 13:38:55 CEST 2019             |
|                                          |
| Type in the IP Addresses                 |
+------------------------------------------+
Master IP: 192.168.50.10
Amount of Minions: 2
Set Minion 1 ip address: 192.168.50.11
Set Minion 2 ip address: 192.168.50.12
...
...
...
```
