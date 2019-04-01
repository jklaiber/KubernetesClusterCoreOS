# Deploy Cert-Manager on Nginx-Ingress

Follow the Instruction [here](link) for the Load Balancer.


```
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml
```
Add a label to the `kube-system` namespace to enable advanced resource validation.
```
kubectl label namespace kube-system certmanager.k8s.io/disable-validation="true"
```
Create a new namespace
```
kubectl create namespace cert-manager
```
Install the cert-manager
```
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.7/deploy/manifests/cert-manager.yaml
```
Create a new file called `prod_issuer.yaml`
```yaml
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: your_email_address_here
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    # Enable the HTTP-01 challenge provider
    http01: {}
```
**Note:** Don't forget to change the Email  

Example of an application ingress file with enabled Certificat
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: echo-ingress
  annotations:  
    kubernetes.io/ingress.class: nginx
    # Certificat Issuer
    certmanager.k8s.io/cluster-issuer: letsencrypt-prod
spec:
  # tls infos
  tls:
  - hosts:
    - echo1.example.com
    - echo2.example.com
    secretName: letsencrypt-prod
  rules:
  - host: echo1.example.com
    http:
      paths:
      - backend:
          serviceName: echo1
          servicePort: 80
  - host: echo2.example.com
    http:
      paths:
      - backend:
          serviceName: echo2
          servicePort: 80
```
You can track the the progress of the certificate creating
```
kubectl describe certificate letsencrypt-prod
```
