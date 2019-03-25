# Monitor Cluster with Prometheus
<img src="https://cdn-images-1.medium.com/max/800/1*zwH6_X8uWpXAzLt4FLdyOw.png" alt="Prometheus Logo" style="height: 105px"/>

## Content
* [Grant Permissions](link)
* [Deploy Prometheus](link)
* [Access Prometheus](link)
  * [With Expose](link)
  * [With Traefik](link)

## Grant Permissions
Prometheus have to access pods, endpoints and services running in your cluster so we have to grant him this permissions.  

```yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - configmaps
  verbs: ["get"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
```
Prometheus have now the following permissions:
* Read and watch access to pods, nodes, services and endpoints
* Read access to `ConfigMaps`
* Read access to non-resource URLs such as `/metrics`    

We also have to create a `ServiceAccount`
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
```
Now we have to bind the `ServiceAccount` and `ClusterRole` using the `ClusterRoleBinding`
```yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: default
```
## Deploy Prometheus
Save the configuration (`prometheus.yml`)
```yaml
global:
  scrape_interval: 15s
  external_labels:
    monitor: 'codelab-monitor'
scrape_configs:
- job_name: 'prometheus'
  scrape_interval: 5s
  static_configs:
  - targets: ['localhost:9090']
- job_name: 'kubernetes-service-endpoints'
  kubernetes_sd_configs:
  - role: endpoints
  relabel_configs:
  - action: labelmap
    regex: __meta_kubernetes_service_label_(.+)
  - source_labels: [__meta_kubernetes_namespace]
    action: replace
    target_label: kubernetes_namespace
  - source_labels: [__meta_kubernetes_service_name]
    action: replace
    target_label: kubernetes_name
```
**Note:** Full list of available configuration see [Prometheus documentation](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#%3Ckubernetes_sd_config)  

Run `kubectl create configmap prometheus-config --from-file prometheus.yml`  

Create the deployment file and save it as `prometheus-deployment.yml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus-cont
        image: prom/prometheus
        volumeMounts:
        - name: config-volume
          mountPath: /etc/prometheus/prometheus.yml
          subPath: prometheus.yml
        ports:
        - containerPort: 9090
      volumes:
      - name: config-volume
        configMap:
          name: prometheus-config
      serviceAccountName: prometheus
```
## Access Prometheus
### With Expose
When you want to access the web interface over a specific port you can use Expose
```yaml
kind: Service
apiVersion: v1
metadata:
  name: prometheus-service
spec:
  selector:
    app: prometheus
  ports:
  - name: promui
    nodePort: 30900
    protocol: TCP
    port: 9090
    targetPort: 9090
  type: NodePort
```
Save the service under `prometheus-expose-service.yml`  

Run `kubectl create -f prometheus-expose-service.yml`  

Lookup the URL `kubectl service prometheus-service --url`
### With Traefik
When you use Traefik you can go with the following steps.  

Create a new service (`prometheus-traefik-service.yml`)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
spec:
  ports:
  - name: promui
    targetPort: 9090
    port: 9090
    protocol: TCP
  selector:
    app: prometheus
```
Run `kubectl create -f prometheus-traefik-service.yml`  

Create a new ingress file (`prometheus-traefik-ingress.yml`)
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: prometheus
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: prometheus.minikube
    http:
      paths:
      - path: /
        backend:
          serviceName: prometheus-service
          servicePort: 9090
```
Run `kubectl create -f prometheus-traefik-ingress.yml`
