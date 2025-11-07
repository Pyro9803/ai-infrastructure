# Step-by-Step Guide: Deploy AI Models on Ray Cluster with Kubernetes

## Prerequisites
- Kubernetes cluster (GKE, EKS, or local)
- kubectl configured
- GPU nodes with appropriate labels and taints (optional, for GPU inference)
- KubeRay operator installed

## Table of Contents
1. [Install KubeRay Operator](#1-install-kuberay-operator)
2. [Create RayCluster Configuration](#2-create-raycluster-configuration)
3. [Deploy Ray Cluster](#3-deploy-ray-cluster)
4. [Troubleshoot Common Issues](#4-troubleshoot-common-issues)
5. [Prepare Model Deployment Script](#5-prepare-model-deployment-script)
6. [Deploy the AI Model](#6-deploy-the-ai-model)
7. [Test Your Model](#7-test-your-model)
8. [Monitor and Scale](#8-monitor-and-scale)

---

## 1. Install KubeRay Operator

```bash
# Install KubeRay operator
kubectl create -k "github.com/ray-project/kuberay/ray-operator/config/default?ref=v1.4.2&timeout=90s"

# Verify installation
kubectl get pods -n ray-system
```

---

## 2. Create RayCluster Configuration

Create `ray-cluster-gpu.yaml`:

```yaml
apiVersion: ray.io/v1
kind: RayCluster
metadata:
  name: ray-cluster-gpu
  namespace: default
spec:
  rayVersion: '2.36.0'
  
  # Head node configuration
  headGroupSpec:
    serviceType: ClusterIP
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray:2.36.0
          imagePullPolicy: IfNotPresent
          ports:
          - containerPort: 6379    # Ray GCS
          - containerPort: 8265    # Dashboard
          - containerPort: 10001   # Ray Client
          resources:
            limits:
              cpu: "2"
              memory: "4Gi"
            requests:
              cpu: "1"
              memory: "2Gi"
  
  # Worker nodes configuration
  workerGroupSpecs:
  - groupName: gpu-workers
    replicas: 1
    minReplicas: 1
    maxReplicas: 3
    template:
      spec:
        containers:
        - name: ray-worker
          image: rayproject/ray:2.36.0
          imagePullPolicy: IfNotPresent
          env:
          - name: NVIDIA_VISIBLE_DEVICES
            value: all
          resources:
            limits:
              cpu: "2"
              memory: "8Gi"
              nvidia.com/gpu: 1
            requests:
              cpu: "1"
              memory: "4Gi"
        
        # GPU node selector
        nodeSelector:
          cloud.google.com/gke-accelerator: nvidia-tesla-t4
        
        # GPU tolerations
        tolerations:
        - effect: NoSchedule
          key: nvidia.com/gpu
          operator: Exists
        - effect: NoSchedule
          key: nvidia.com/gpu-type
          operator: Exists
```

**Important Notes:**
- **Do NOT include custom `command` sections** - let KubeRay auto-generate Ray start commands
- Adjust node selectors and tolerations based on your cluster configuration
- For CPU-only deployments, remove GPU-related configurations

---

## 3. Deploy Ray Cluster

```bash
# Apply the configuration
kubectl apply -f ray-cluster-gpu.yaml

# Watch pods start
kubectl get pods -w

# Expected output:
# NAME                                  READY   STATUS    RESTARTS   AGE
# ray-cluster-gpu-head-xxxxx           1/1     Running   0          2m
# ray-cluster-gpu-gpu-workers-xxxxx    1/1     Running   0          2m
```

---

## 4. Troubleshoot Common Issues

### Issue 1: Head Pod CrashLoopBackOff

**Symptom:** Head pod keeps restarting

**Cause:** Double Ray start command (custom command + KubeRay auto-generated)

**Solution:** Remove custom command sections, let KubeRay manage startup

```bash
kubectl edit raycluster ray-cluster-gpu
# Remove any custom command/args from headGroupSpec
```

### Issue 2: Worker Pod Pending

**Symptom:** Worker pod stuck in Pending state

**Check:**
```bash
kubectl describe pod <worker-pod-name>
```

**Common causes and solutions:**

a) **Untolerated taints:**
```
Events:
  Warning  FailedScheduling  node(s) had untolerated taint {nvidia.com/gpu-type: nvidia-tesla-t4}
```

**Solution:** Add proper tolerations (see configuration above)

b) **No GPU nodes available:**
```bash
# Check GPU nodes
kubectl get nodes -o json | grep nvidia
```

**Solution:** Add GPU node pool to your cluster

### Issue 3: GPU Not Detected by Ray

**Check Ray status:**
```bash
kubectl exec -it <head-pod-name> -- ray status
```

**Expected output should show GPU:**
```
Resources
---------------------------------------------------------------
Usage:
 0.0/4.0 CPU
 0.0/1.0 GPU  ← This should appear
```

**If GPU not shown:** Worker's Ray start command missing `--num-gpus=1`

**Solution:** Ensure no custom commands in worker spec

---

## 5. Prepare Model Deployment Script

Create `deploy_model.py` on your local machine:

```python
import ray
from ray import serve
from starlette.requests import Request
from starlette.responses import JSONResponse

@serve.deployment(
    num_replicas=1,
    ray_actor_options={"num_gpus": 1}  # Use 1 GPU
)
class TextGenerator:
    def __init__(self):
        print("Loading model...")
        from transformers import pipeline
        self.generator = pipeline(
            'text-generation',
            model='gpt2',
            device=0  # GPU device
        )
        print("Model loaded successfully!")
    
    async def __call__(self, request: Request):
        data = await request.json()
        prompt = data.get("prompt", "Hello")
        max_length = data.get("max_length", 50)
        
        result = self.generator(
            prompt,
            max_length=max_length,
            num_return_sequences=1
        )
        
        return JSONResponse({
            "input": prompt,
            "output": result[0]['generated_text']
        })

# Start Ray Serve and deploy
serve.start(detached=True)
serve.run(
    TextGenerator.bind(),
    name="text-generator",
    route_prefix="/generate"
)

print("Model service deployed successfully!")
print("Service is running at: http://localhost:8000/generate")
```

**For CPU-only deployment:**
```python
ray_actor_options={"num_cpus": 1}  # Use CPU instead
device=-1  # CPU device in pipeline
```

---

## 6. Deploy the AI Model

### Step 1: Copy script to Ray head pod

```bash
# Get head pod name
HEAD_POD=$(kubectl get pods | grep ray-cluster-gpu-head | awk '{print $1}')

# Copy script
kubectl cp deploy_model.py $HEAD_POD:/tmp/deploy_model.py
```

### Step 2: Install dependencies on worker nodes

```bash
# Get worker pod name
WORKER_POD=$(kubectl get pods | grep gpu-workers | awk '{print $1}')

# Install dependencies
kubectl exec -it $WORKER_POD -- pip install transformers torch accelerate
```

**Note:** This may take 5-10 minutes

### Step 3: Deploy the model

```bash
kubectl exec -it $HEAD_POD -- python /tmp/deploy_model.py
```

**Expected output:**
```
Loading model...
Model loaded successfully!
Deployment 'TextGenerator' is ready at `http://127.0.0.1:8000/generate`
Model service deployed successfully!
```

---

## 7. Test Your Model

### Step 1: Port forward

```bash
kubectl port-forward $HEAD_POD 8000:8000
```

Keep this terminal open.

### Step 2: Send test requests

Open another terminal:

```bash
# Test 1: Simple generation
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Once upon a time", "max_length": 100}'

# Test 2: Custom prompt
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "The future of AI is", "max_length": 150}'
```

**Expected response:**
```json
{
  "input": "Once upon a time",
  "output": "Once upon a time there was a..."
}
```

---

## 8. Monitor and Scale

### Access Ray Dashboard

```bash
kubectl port-forward $HEAD_POD 8265:8265
```

Open browser: `http://localhost:8265`

Dashboard shows:
- Service health
- GPU utilization
- Request metrics
- Logs

### Check Ray cluster status

```bash
kubectl exec -it $HEAD_POD -- ray status
```

### Scale deployments

**Scale workers:**
```bash
kubectl edit raycluster ray-cluster-gpu
# Change replicas: 1 to replicas: 3
```

**Scale model replicas (in Python):**
```python
from ray import serve

# Update to 2 replicas
serve.get_deployment("TextGenerator").options(num_replicas=2).deploy()
```

---

## Alternative: Using Runtime Environment

To automatically install dependencies without manual installation:

```python
@serve.deployment(
    num_replicas=1,
    ray_actor_options={
        "num_gpus": 1,
        "runtime_env": {
            "pip": ["transformers", "torch", "accelerate"]
        }
    }
)
class TextGenerator:
    # ... rest of the code
```

This approach automatically installs packages when the deployment starts.

---

## Best Practices

1. **Let KubeRay manage Ray commands** - Don't use custom startup commands
2. **Use runtime environments** - Automatically handle dependencies
3. **Monitor GPU usage** - Check dashboard for utilization
4. **Start small** - Test with CPU before moving to GPU
5. **Version control** - Keep RayCluster configs in git
6. **Resource limits** - Set appropriate CPU/memory/GPU limits
7. **Health checks** - Monitor via Ray dashboard
8. **Log aggregation** - Use `kubectl logs` for debugging

---

## Common Commands Reference

```bash
# Check cluster status
kubectl get raycluster
kubectl get pods

# View logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Previous crash

# Debug pod
kubectl describe pod <pod-name>
kubectl exec -it <pod-name> -- bash

# Ray commands
kubectl exec -it <head-pod> -- ray status
kubectl exec -it <head-pod> -- ray list actors

# Clean up
kubectl delete raycluster ray-cluster-gpu
```

---

## Troubleshooting Checklist

- [ ] KubeRay operator running
- [ ] Head pod running (1/1 Ready)
- [ ] Worker pods running (1/1 Ready)
- [ ] GPU visible in `ray status` (if using GPU)
- [ ] Dependencies installed on worker nodes
- [ ] Model deployment successful
- [ ] Port forwarding working
- [ ] Service responding to requests

---

## Next Steps

1. **Deploy larger models** - Llama, Mistral, etc.
2. **Add authentication** - Secure your endpoints
3. **Set up ingress** - Expose externally
4. **Configure autoscaling** - Dynamic scaling based on load
5. **Add monitoring** - Prometheus/Grafana
6. **Implement CI/CD** - Automated deployments

---

## Resources

- [Ray Documentation](https://docs.ray.io/)
- [KubeRay Documentation](https://docs.ray.io/en/latest/cluster/kubernetes/index.html)
- [Ray Serve Documentation](https://docs.ray.io/en/latest/serve/index.html)
- [Transformers Documentation](https://huggingface.co/docs/transformers)