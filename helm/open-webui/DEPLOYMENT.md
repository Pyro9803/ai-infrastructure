# Open WebUI Helm Chart Deployment Guide

This Helm chart deploys Open WebUI with separate frontend (nginx) and backend (Python API) containers.

## Prerequisites

1. **Build and push your Docker images** to a registry accessible by your Kubernetes cluster:

```bash
# Tag images for your registry
docker tag open-webui-fe:latest <your-registry>/open-webui-fe:latest
docker tag open-webui-be:latest <your-registry>/open-webui-be:latest

# Push to registry
docker push <your-registry>/open-webui-fe:latest
docker push <your-registry>/open-webui-be:latest
```

2. **Update values.yaml** with your registry:

```yaml
frontend:
  image:
    repository: <your-registry>/open-webui-fe
    tag: "latest"

backend:
  image:
    repository: <your-registry>/open-webui-be
    tag: "latest"
```

## Installation

### 1. Install the Helm chart

```bash
cd helm/open-webui

# Install
helm install open-webui . -n open-webui --create-namespace

# Or upgrade if already installed
helm upgrade --install open-webui . -n open-webui --create-namespace
```

### 2. Check deployment status

```bash
# Check pods
kubectl get pods -n open-webui

# Check services
kubectl get svc -n open-webui

# Check logs
kubectl logs -n open-webui -l app.kubernetes.io/name=open-webui -c frontend
kubectl logs -n open-webui -l app.kubernetes.io/name=open-webui -c backend
```

### 3. Access the application

#### Port Forward (for testing)
```bash
kubectl port-forward -n open-webui svc/open-webui 8080:80
```

Then access at http://localhost:8080

#### Ingress (for production)

Create an ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: open-webui
  namespace: open-webui
spec:
  rules:
  - host: open-webui.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: open-webui
            port:
              number: 80
```

## Configuration

### Key values.yaml settings:

```yaml
# Scale replicas
replicaCount: 3

# Resource limits
backend:
  resources:
    limits:
      cpu: 2000m
      memory: 4Gi

# Persistence
persistence:
  enabled: true
  size: 10Gi
  storageClass: "fast-ssd"  # Your storage class

# Environment variables
env:
  WEBUI_SECRET_KEY: "your-secret-key"
  ENABLE_SIGNUP: "false"
  DEFAULT_USER_ROLE: "user"
```

## Architecture

```
┌─────────────────┐
│   Ingress/LB    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Service (80)   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│         Pod                     │
│  ┌──────────┐  ┌──────────┐   │
│  │ Frontend │  │ Backend  │   │
│  │  nginx   │  │  Python  │   │
│  │  :80     │  │  :8080   │   │
│  └──────────┘  └──────────┘   │
│                    │            │
│                    ▼            │
│              ┌──────────┐      │
│              │   PVC    │      │
│              │ /app/... │      │
│              └──────────┘      │
└─────────────────────────────────┘
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod -n open-webui <pod-name>
kubectl logs -n open-webui <pod-name> -c frontend
kubectl logs -n open-webui <pod-name> -c backend
```

### Image pull errors
- Ensure images are pushed to your registry
- Update imagePullSecrets if using private registry
- Verify image tags in values.yaml

### Database issues
```bash
# Check PVC
kubectl get pvc -n open-webui

# Exec into backend container
kubectl exec -it -n open-webui <pod-name> -c backend -- /bin/bash
ls -la /app/backend/data/
```

## Uninstall

```bash
helm uninstall open-webui -n open-webui

# Delete PVC if needed
kubectl delete pvc -n open-webui --all

# Delete namespace
kubectl delete namespace open-webui
```
