# Notification with Kubewatch trough slack
Create new slack BOT
```
https://<your_organization>.slack.com/apps/new/bot
```
Create Configmap (`kubewatch-config.yaml` for kubewatch. Replace Slack API token and channel name.
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubewatch
data:
  .kubewatch.yaml: |
    handler:
      slack:
        token: <SLACK_API_TOKEN>
        channel: <SLACK_CHANNEL_NAME>
    resource:
      deployment: true
      replicationcontroller: true
      replicaset: true
      daemonset: true
      services: true
      pod: true
```
Execute command:
`kubectl create -f kubewatch-config.yaml`

Create (`rbac.yaml`) service account, cluster role...
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kubewatch
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kubewatch
rules:
- apiGroups:
  - ""
  resources:
  - endpoints
  - services
  - pods
  - namespaces
  - replicationcontrollers
  verbs:
  - list
  - watch
  - get
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kubewatch
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kubewatch
subjects:
- kind: ServiceAccount
  name: kubewatch
  namespace: monitoring
```
Execute command: `kubectl create -f rbac.yaml`

Create Deployment yaml file (`kubewatch.yaml`)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubewatch
  namespace: monitoring
spec:
  containers:
  - image: tuna/kubewatch:v0.0.1
    imagePullPolicy: Always
    name: kubewatch
    volumeMounts:
    - name: config-volume
      mountPath: /root
  - image: gcr.io/skippbox/kubectl:v1.3.0
    args:
      - proxy
      - "-p"
      - "8080"
    name: proxy
    imagePullPolicy: Always
  restartPolicy: Always
  serviceAccount: kubewatch
  serviceAccountName: kubewatch
  volumes:
  - name: config-volume
    configMap:
      name: kubewatch
```
Execute command: `kubectl create -f kubewatch.yaml`
