---
title: "Deploying Unifi Controller to Kubernetes"
date: 2023-07-22T09:40:29+02:00
tags: ["homelab", "kubernetes", "DevOps", "Unifi", "networking"]
cover:
  image: "unifi-controller-on-kubernetes.png"
  alt: "Deploying Unifi Controller to Kubernetes"
---

I would like to share with you my manifest to deploy [Unifi Controller](https://hub.docker.com/r/jacobalberty/unifi/) to my homelab k8s cluster. The config is based on [this thread on unifi community forum](https://community.ui.com/questions/How-to-configure-BGP-routing-on-USG-Pro-4/ecdfecb5-a8f5-48a5-90da-cc68d054be11)

I wanted to deploy Unifi Controller, this way to easily control `config.gateway.json` which can persist the non-standard config for router. Without `config.gateway.json`, the BGP configuration is lost after the router restart. I wanted the BGP config for [MetalLB](https://metallb.universe.tf/concepts/bgp/)

This manifest has several assumptions:
* the TLS certificate is obtain via [cert-manager](https://cert-manager.io)
* MetalLB is installed on cluster
* BGP is configured manually on [USG-PRO-4](https://eu.store.ui.com/eu/en/pro/category/all-unifi-gateway-consoles/products/unifi-security-gateway-pro) router
* [Traefik](https://doc.traefik.io/traefik/) is controlling the ingresses

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: unifi-cert
spec:
  secretName: unifi-cert-secret
  dnsNames:
    - xxx.com
    - unifi.xxx.com
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
    group: cert-manager.io
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-unifi
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 8Gi
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: unifi-controller
spec:
  replicas: 1
  selector:
    matchLabels:
      name: unifi-controller
  template:
    metadata:
      name: unifi-controller
      labels:
        name: unifi-controller
    spec:
      volumes:
        - name: nfs-unifi
          persistentVolumeClaim:
            claimName: nfs-unifi
        - name: unifi-cert
          secret:
            secretName: unifi-cert-secret
        - name: config
          configMap:
            name: config-gateway
            items:
              - key: config.gateway.json
                path: config.gateway.json
      containers:
        - name: unifi-controller
          image: 'jacobalberty/unifi:v7.4.156'
          env:
            - name: TZ
              value: "Europe/Warsaw"
            - name: UNIFI_STDOUT
              value: "true"
          ports:
            - containerPort: 3478
              protocol: UDP
            - containerPort: 10001
              protocol: UDP
            - containerPort: 8080
              protocol: TCP
            - containerPort: 8443
              protocol: TCP
            - containerPort: 8843
              protocol: TCP
            - containerPort: 8880
              protocol: TCP
            - containerPort: 6789
              protocol: TCP
          volumeMounts:
            - name: nfs-unifi
              mountPath: /unifi
            - name: unifi-cert
              mountPath: /unifi/cert
              readOnly: true
            - name: config
              mountPath: /unifi/data/sites/default
              readOnly: true
---
kind: Service
apiVersion: v1
metadata:
  name: lb-unifi
  annotations:
    metallb.universe.tf/allow-shared-ip: 'true'
spec:
  ports:
    - name: '8080'
      protocol: TCP
      port: 8080
      targetPort: 8080
    - name: '8443'
      protocol: TCP
      port: 8443
      targetPort: 8443
    - name: '8843'
      protocol: TCP
      port: 8843
      targetPort: 8843
    - name: '8880'
      protocol: TCP
      port: 8880
      targetPort: 8880
    - name: '6789'
      protocol: TCP
      port: 6789
      targetPort: 6789
  selector:
    name: unifi-controller
  type: LoadBalancer
  loadBalancerIP: 192.168.1.82
---
kind: Service
apiVersion: v1
metadata:
  name: lb-unifi-udp
  annotations:
    metallb.universe.tf/allow-shared-ip: 'true'
spec:
  ports:
    - name: '3478'
      protocol: UDP
      port: 3478
      targetPort: 3478
    - name: '10001'
      protocol: UDP
      port: 10001
      targetPort: 10001
  selector:
    name: unifi-controller
  type: LoadBalancer
  loadBalancerIP: 192.168.1.82
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: unifi-controller
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      match: Host(`unifi.xxx.com`)
      services:
        - name: lb-unifi
          port: 8443
          scheme: https
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-gateway
data:
  config.gateway.json: |
    {
        "protocols": {
            "bgp": {
                "64501": {
                    "neighbor": {
                        "192.168.1.51": { "remote-as": "64500" },
                        "192.168.1.52": { "remote-as": "64500" },
                        "192.168.1.53": { "remote-as": "64500" }
                    },
                    "parameters": {
                        "router-id": "192.168.1.1"
                    }
                }
            }
        }
    }
```
