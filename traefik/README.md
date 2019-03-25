# Traefik Reverse Proxy
<img src="https://cdn-images-1.medium.com/max/1200/1*g7vZlZ5KLEjvf0eeD65jbQ.png" alt="Traefik Reverse Proxy Kubernetes" />

## Content
* [Service Accounts](link)
* [Deploy Traefik](link)
* [Create a Service](link)

## Service Accounts
Create a new ServiceAccount for Traefik `traefik-service-acc.yaml`
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-ingress
  namespace: kube-system
```
Run `kubectl create -f traefik-service-acc.yaml`

Traefik needs to manage and watch resources like Services, Endpoints, Secrets and Ingresses across all namespaces.

Create a new file and call it `traefik-rights.yaml`
```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress
rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
```
Run `kubectl create -f traefik-rights.yaml`

Now we have to enable these permissions. Create a new file called `traefik-crb.yaml`
```yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress
subjects:
- kind: ServiceAccount
  name: traefik-ingress
  namespace: kube-system
```
Run `kubectl create -f traefik-crb.yaml`

## Deploy Traefik
Create a deployment file and call it `traefik-deployment.yaml`
```yaml
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: traefik-ingress
  namespace: kube-system
  labels:
    k8s-app: traefik-ingress-lb
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: traefik-ingress-lb
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress-lb
        name: traefik-ingress-lb
    spec:
      serviceAccountName: traefik-ingress
      terminationGracePeriodSeconds: 60
      containers:
      - image: traefik
        name: traefik-ingress-lb
        ports:
        - name: http
          containerPort: 80
        - name: admin
          containerPort: 8080
        args:
        - --api
        - --kubernetes
        - --logLevel=INFO
```
Run `kubectl create -f traefik-deployment.yaml`  

Check if the Traefik Pods were successfully created:
`kubectl --namespace=kube-system get pods`

## Create a Service
