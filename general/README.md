# Kubernetes Manuals

## Content
* [Deployment of Apps](link)
* [List](link)
* [Describe](link)
* [Scaling](link)
* [Debug](link)

**Note:** Get more commands from the official **[cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)**

## Deployment of Apps
```bash
# With create you have to redeploy the app when you made changes
[user@localhost]$ kubectl create -f <yaml file>
```
```bash
# With apply you can change the config of a deployed app
[user@localhost]$ kubectl apply -f <yaml file>
```

## List
```bash
# List all services in the namespace
[user@localhost]$ kubectl get services

# List all pods in all namespaces
[user@localhost]$ kubectl get pods --all-namespaces

# List all pods in the namespace, with more details
[user@localhost]$ kubectl get pods -o wide  

# List a particular deployment
[user@localhost]$ kubectl get deployment <deployment name>

# List all pods in the namespace, including uninitialized ones
[user@localhost]$ kubectl get pods --include-uninitialized

# Get a pod's YAML
[user@localhost]$ kubectl get pod <pod name> -o yaml
```

## Describe
```bash
# Describe node
[user@localhost]$ kubectl describe nodes <node name>

#Describe pod
[user@localhost]$ kubectl describe pods <pod name>
```
## Scaling
```bash
# Scale a replicaset
[user@localhost]$ kubectl scale --replicas=<number of replicas> <pod name>

# Scale a resource specified in a yaml file
[user@localhost]$ kubectl scale --replicas=<number of replicas> -f <yaml file>

# Scale multiple replication controllers
[user@localhost]$ kubectl scale --replicas=<number of replicas> <pod name 1> <pod name 2>  
```

## Debug

**Watch**
```bash
# Watch all Namespaces
[user@localhost]$ watch kubectl get pods --all-namespaces

# Watch all Namespaces with IP Addresses
[user@localhost]$ watch kubectl get pods --all-namespaces -o wide
```

**Bash inside Pod**
```bash
[user@localhost]$ kubectl exec -it <pod name> /bin/bash
```

**Get log Information**
```bash
# You must give the name of the namespace
[user@localhost]$ kubectl logs -n <namespace> <pod name>
```
