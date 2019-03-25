# Traefik Reverse Proxy
<img src="https://cdn-images-1.medium.com/max/1200/1*g7vZlZ5KLEjvf0eeD65jbQ.png" alt="Traefik Reverse Proxy Kubernetes" />

## Content
* [Service Accounts](link)
* [Deploy Traefik](link)
* [Create a Service](link)
* [Adding Ingress to the Cluster](link)
* [Implement Name-Based Routing](link)
  * [Serve different frontends under one domain](link)

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
We need services to access Pods from within or outside the cluster. We need a service to access Traefik Ingress Pods. Create a new file and call it `traefik-service.yaml`
```yaml
kind: Service
apiVersion: v1
metadata:
  name: traefik-ingress-service
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress-lb
  ports:
    - protocol: TCP
      port: 80
      name: web
    - protocol: TCP
      port: 8080
      name: admin
  type: NodePort
```
Run `kubectl create -f traefik-service.yaml`  

## Adding Ingress to the Cluster
Now we have to define the Ingress resource and a Service which exposes the Traefik Web UI. Create a new file and called it `traefik-webui.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik-web-ui
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress-lb
  ports:
  - name: web
    port: 80
    targetPort: 8080
```
Run `kubectl create -f traefik-webui.yaml`  

Now create a new file called `traefik-ingress.yaml` which will route all request to `[Traefik Hostname]`
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: traefik-web-ui
  namespace: kube-system
spec:
  rules:
  - host: [Traefik Hostname]
    http:
      paths:
      - path: /
        backend:
          serviceName: traefik-web-ui
          servicePort: web
```
Run `kubectl create -f traefik-ingress.yaml`  

**Note:** You have to point a DNS Entry to your Cluster IP to access the Traefik Web UI

## Implement Name-Based Routing
We need for every deployment we make a service and a Ingress manifest which Traefik use to expose the app.  

Make a new deployment
```yaml
---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: bear
  labels:
    app: animals
    animal: bear
spec:
  replicas: 2
  selector:
    matchLabels:
      app: animals
      task: bear
  template:
    metadata:
      labels:
        app: animals
        task: bear
        version: v0.0.1
    spec:
      containers:
      - name: bear
        image: supergiantkir/animals:bear
        ports:
        - containerPort: 80
---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: moose
  labels:
    app: animals
    animal: moose
spec:
  replicas: 2
  selector:
    matchLabels:
      app: animals
      task: moose
  template:
    metadata:
      labels:
        app: animals
        task: moose
        version: v0.0.1
    spec:
      containers:
      - name: moose
        image: supergiantkir/animals:moose
        ports:
        - containerPort: 80
```
And create a new Service
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: bear
spec:
  ports:
  - name: http
    targetPort: 80
    port: 80
  selector:
    app: animals
    task: bear
---
apiVersion: v1
kind: Service
metadata:
  name: moose
spec:
  ports:
  - name: http
    targetPort: 80
    port: 80
  selector:
    app: animals
    task: moose
```
Create the ingress manifest
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: animals
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: bear.minikube
    http:
      paths:
      - path: /
        backend:
          serviceName: bear
          servicePort: http
  - host: moose.minikube
    http:
      paths:
      - path: /
        backend:
          serviceName: moose
          servicePort: http
```
### Serve different frontends under one domain
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: animals
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.frontend.rule.type: PathPrefixStrip
spec:
  rules:
  - host: animals.minikube
    http:
      paths:
      - path: /bear
        backend:
          serviceName: bear
          servicePort: http
      - path: /moose
        backend:
          serviceName: moose
          servicePort: http
```
Now we can access the applications with `animals.minikube/bear`
