# Deploy Open-Source GPT Models on Fresh GKE Cluster

Complete guide to deploy large language models (Llama, Mistral, GPT-J) on Google Kubernetes Engine from scratch.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Create GKE Cluster with GPU](#create-gke-cluster-with-gpu)
3. [Install Required Components](#install-required-components)
4. [Deploy Ray Cluster](#deploy-ray-cluster)
5. [Deploy GPT Model](#deploy-gpt-model)
6. [Test and Monitor](#test-and-monitor)
7. [Production Setup](#production-setup)

---

## Prerequisites

### Local Setup

```bash
# Install gcloud CLI
# https://cloud.google.com/sdk/docs/install

# Install kubectl
gcloud components install kubectl

# Authenticate
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Install helm (for KubeRay)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Set Variables

```bash
export PROJECT_ID="your-project-id"
export CLUSTER_NAME="llm-cluster"
export REGION="us-central1"
export ZONE="us-central1-a"

gcloud config set project $PROJECT_ID
```

---

## Step 1: Create GKE Cluster with GPU

### Option A: Standard Cluster (Recommended for Production)

```bash
# Create standard cluster with CPU nodes
gcloud container clusters create $CLUSTER_NAME \
  --region=$REGION \
  --machine-type=n1-standard-4 \
  --num-nodes=2 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=5 \
  --disk-size=100 \
  --disk-type=pd-standard \
  --enable-ip-alias \
  --network="default" \
  --subnetwork="default" \
  --logging=SYSTEM,WORKLOAD \
  --monitoring=SYSTEM

# Add GPU node pool (for model inference)
gcloud container node-pools create gpu-pool \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --machine-type=n1-standard-4 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --num-nodes=1 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=3 \
  --disk-size=100 \
  --node-taints=nvidia.com/gpu=present:NoSchedule \
  --node-labels=workload=gpu-inference

# Get credentials
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION
```

### Option B: Autopilot Cluster (Simpler, More Expensive)

```bash
# Create autopilot cluster (GPU support built-in)
gcloud container clusters create-auto $CLUSTER_NAME \
  --region=$REGION \
  --release-channel=regular

# Get credentials
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION
```

### Install NVIDIA GPU Drivers

```bash
# Apply NVIDIA device plugin daemonset
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/cos/daemonset-preloaded.yaml

# Verify GPU nodes
kubectl get nodes -o json | jq '.items[].status.capacity."nvidia.com/gpu"'
```

---

## Step 2: Install Required Components

### Install KubeRay Operator (via Helm)

```bash
# Add KubeRay Helm repository
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

# Install KubeRay operator
helm install kuberay-operator kuberay/kuberay-operator \
  --namespace ray-system \
  --create-namespace \
  --version 1.4.2

# Verify installation
kubectl get pods -n ray-system
```

### Create Namespace

```bash
kubectl create namespace llm-inference
kubectl config set-context --current --namespace=llm-inference
```

---

## Step 3: Deploy Ray Cluster

### Create RayCluster Configuration

Create `ray-cluster-llm.yaml`:

```yaml
apiVersion: ray.io/v1
kind: RayCluster
metadata:
  name: ray-cluster-llm
  namespace: llm-inference
spec:
  rayVersion: '2.36.0'
  enableInTreeAutoscaling: true
  
  # Head node - no GPU needed
  headGroupSpec:
    serviceType: LoadBalancer  # External access
    rayStartParams:
      dashboard-host: '0.0.0.0'
      num-cpus: '0'  # Don't schedule workload on head
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray-ml:2.36.0-gpu  # GPU-enabled image
          imagePullPolicy: IfNotPresent
          ports:
          - containerPort: 6379
            name: gcs
          - containerPort: 8265
            name: dashboard
          - containerPort: 10001
            name: client
          - containerPort: 8000
            name: serve
          resources:
            limits:
              cpu: "4"
              memory: "16Gi"
            requests:
              cpu: "2"
              memory: "8Gi"
          env:
          - name: RAY_GRAFANA_IFRAME_HOST
            value: "http://127.0.0.1:3000"
  
  # Worker nodes - with GPU
  workerGroupSpecs:
  - groupName: gpu-workers
    replicas: 1
    minReplicas: 0
    maxReplicas: 3
    rayStartParams:
      num-gpus: "1"
    template:
      spec:
        containers:
        - name: ray-worker
          image: rayproject/ray-ml:2.36.0-gpu
          imagePullPolicy: IfNotPresent
          resources:
            limits:
              cpu: "4"
              memory: "16Gi"
              nvidia.com/gpu: "1"
            requests:
              cpu: "2"
              memory: "8Gi"
              nvidia.com/gpu: "1"
          env:
          - name: NVIDIA_VISIBLE_DEVICES
            value: "all"
          - name: CUDA_VISIBLE_DEVICES
            value: "0"
        
        # GPU node selector and tolerations
        nodeSelector:
          workload: gpu-inference
        
        tolerations:
        - key: nvidia.com/gpu
          operator: Equal
          value: present
          effect: NoSchedule
```

### Deploy Ray Cluster

```bash
kubectl apply -f ray-cluster-llm.yaml

# Wait for pods to be ready (may take 5-10 minutes)
kubectl get pods -w

# Check Ray cluster status
kubectl get raycluster ray-cluster-llm
```

---

## Step 4: Deploy GPT Model

### Choose Your Model

**Model Options:**

| Model | Size | GPU Memory | Context | Use Case |
|-------|------|------------|---------|----------|
| GPT-2 | 1.5GB | 4GB | 1024 | Testing |
| GPT-J-6B | 24GB | 24GB | 2048 | General |
| Llama-2-7B | 14GB | 16GB | 4096 | Chat/General |
| Mistral-7B | 14GB | 16GB | 8192 | Best quality |
| Llama-3-8B | 16GB | 18GB | 8192 | Latest |

**For T4 GPU (16GB):** Use Llama-2-7B or Mistral-7B with 8-bit quantization

### Create Deployment Script

Create `deploy_llm.py`:

```python
from ray import serve
from starlette.requests import Request
from starlette.responses import JSONResponse
import torch

@serve.deployment(
    num_replicas=1,
    max_ongoing_requests=5,
    ray_actor_options={
        "num_gpus": 1,
        "num_cpus": 2,
        "runtime_env": {
            "pip": [
                "transformers>=4.35.0",
                "torch>=2.0.0",
                "accelerate>=0.24.0",
                "bitsandbytes>=0.41.0",  # For 8-bit quantization
                "sentencepiece>=0.1.99",
                "protobuf>=3.20.0"
            ]
        }
    },
    autoscaling_config={
        "min_replicas": 1,
        "max_replicas": 3,
        "target_ongoing_requests": 3
    }
)
class LLMDeployment:
    def __init__(self):
        print("🚀 Loading LLM model...")
        from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
        
        # Model configuration
        model_id = "mistralai/Mistral-7B-Instruct-v0.2"
        
        # 8-bit quantization config (saves memory)
        quantization_config = BitsAndBytesConfig(
            load_in_8bit=True,
            bnb_8bit_compute_dtype=torch.float16
        )
        
        # Load tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(
            model_id,
            use_fast=True
        )
        self.tokenizer.pad_token = self.tokenizer.eos_token
        
        # Load model
        self.model = AutoModelForCausalLM.from_pretrained(
            model_id,
            quantization_config=quantization_config,
            device_map="auto",
            torch_dtype=torch.float16,
            low_cpu_mem_usage=True
        )
        
        print(f"✅ Model loaded: {model_id}")
        print(f"📊 GPU Memory: {torch.cuda.memory_allocated(0) / 1024**3:.2f} GB")
    
    async def __call__(self, request: Request):
        try:
            data = await request.json()
            prompt = data.get("prompt", "")
            max_tokens = data.get("max_tokens", 256)
            temperature = data.get("temperature", 0.7)
            
            if not prompt:
                return JSONResponse(
                    {"error": "No prompt provided"},
                    status_code=400
                )
            
            # Tokenize
            inputs = self.tokenizer(
                prompt,
                return_tensors="pt",
                padding=True,
                truncation=True,
                max_length=2048
            ).to("cuda")
            
            # Generate
            with torch.no_grad():
                outputs = self.model.generate(
                    **inputs,
                    max_new_tokens=max_tokens,
                    temperature=temperature,
                    do_sample=True,
                    top_p=0.9,
                    repetition_penalty=1.1,
                    pad_token_id=self.tokenizer.eos_token_id
                )
            
            # Decode
            generated_text = self.tokenizer.decode(
                outputs[0],
                skip_special_tokens=True
            )
            
            return JSONResponse({
                "prompt": prompt,
                "generated_text": generated_text,
                "tokens_generated": len(outputs[0]) - len(inputs.input_ids[0])
            })
            
        except Exception as e:
            return JSONResponse(
                {"error": str(e)},
                status_code=500
            )

# Deploy
app = LLMDeployment.bind()
```

### Alternative: Smaller Model for Testing (GPT-2)

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
class GPT2Deployment:
    def __init__(self):
        from transformers import GPT2LMHeadModel, GPT2Tokenizer
        
        self.tokenizer = GPT2Tokenizer.from_pretrained("gpt2-large")
        self.model = GPT2LMHeadModel.from_pretrained(
            "gpt2-large",
            device_map="auto"
        )
        print("✅ GPT-2 Large loaded")
    
    async def __call__(self, request: Request):
        data = await request.json()
        prompt = data.get("prompt", "")
        
        inputs = self.tokenizer(prompt, return_tensors="pt").to("cuda")
        outputs = self.model.generate(
            **inputs,
            max_length=200,
            temperature=0.7,
            do_sample=True
        )
        
        generated = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
        return JSONResponse({"output": generated})

app = GPT2Deployment.bind()
```

### Deploy to Ray Cluster

```bash
# Get head pod name
HEAD_POD=$(kubectl get pods -n llm-inference | grep ray-cluster-llm-head | awk '{print $1}')

# Copy deployment script
kubectl cp deploy_llm.py llm-inference/$HEAD_POD:/tmp/

# Deploy the model (this will take 5-15 minutes)
kubectl exec -it -n llm-inference $HEAD_POD -- \
  python -c "
from ray import serve
import sys
sys.path.insert(0, '/tmp')

serve.start(detached=True)
serve.run(
    target='/tmp/deploy_llm.py:app',
    name='llm-service',
    route_prefix='/generate'
)
"

# Monitor deployment
kubectl logs -f -n llm-inference $HEAD_POD
```

### Quick Deploy with serve.run

```bash
# Enter head pod
kubectl exec -it -n llm-inference $HEAD_POD -- bash

# Install Ray Serve CLI
pip install ray[serve]

# Deploy
serve run /tmp/deploy_llm.py:app \
  --name llm-service \
  --route-prefix /generate \
  --blocking
```

---

## Step 5: Test and Monitor

### Get External IP

```bash
# Get LoadBalancer IP
kubectl get svc -n llm-inference ray-cluster-llm-head-svc

# Wait for EXTERNAL-IP (may take 2-3 minutes)
export LB_IP=$(kubectl get svc -n llm-inference ray-cluster-llm-head-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "LoadBalancer IP: $LB_IP"
```

### Test the Model

```bash
# Test generation
curl -X POST http://$LB_IP:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Explain quantum computing in simple terms:",
    "max_tokens": 200,
    "temperature": 0.7
  }'

# Test chat
curl -X POST http://$LB_IP:8000/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "[INST] What is the capital of France? [/INST]",
    "max_tokens": 100
  }'
```

### Access Ray Dashboard

```bash
# Port forward dashboard
kubectl port-forward -n llm-inference svc/ray-cluster-llm-head-svc 8265:8265

# Open browser
open http://localhost:8265
```

### Monitor GPU Usage

```bash
# Check GPU utilization
WORKER_POD=$(kubectl get pods -n llm-inference | grep gpu-workers | awk '{print $1}')

kubectl exec -it -n llm-inference $WORKER_POD -- nvidia-smi

# Monitor continuously
watch -n 2 "kubectl exec -n llm-inference $WORKER_POD -- nvidia-smi"
```

---

## Step 6: Production Setup

### Add Ingress with HTTPS

Create `ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: llm-ingress
  namespace: llm-inference
  annotations:
    kubernetes.io/ingress.class: "gce"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    kubernetes.io/ingress.allow-http: "false"
spec:
  tls:
  - hosts:
    - llm.yourdomain.com
    secretName: llm-tls
  rules:
  - host: llm.yourdomain.com
    http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: ray-cluster-llm-head-svc
            port:
              number: 8000
```

### Add Authentication

```python
# Add to deployment
from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

app = FastAPI()
security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials.credentials != "your-secret-token":
        raise HTTPException(status_code=401, detail="Invalid token")
    return credentials.credentials

@serve.deployment(
    ray_actor_options={...}
)
@serve.ingress(app)
class SecureLLMDeployment:
    @app.post("/generate")
    async def generate(self, request: Request, token: str = Depends(verify_token)):
        # Your generation code
        pass
```

### Set Up Monitoring

```bash
# Install Prometheus operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Ray exports metrics on port 8080
# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

### Configure Autoscaling

```yaml
# HPA for Ray workers (in ray-cluster-llm.yaml)
workerGroupSpecs:
- groupName: gpu-workers
  replicas: 1
  minReplicas: 1
  maxReplicas: 5
  rayStartParams:
    num-gpus: "1"
  # ... rest of config
```

### Backup and Disaster Recovery

```bash
# Backup Ray cluster config
kubectl get raycluster -n llm-inference ray-cluster-llm -o yaml > backup-ray-cluster.yaml

# Save deployment script
kubectl exec -n llm-inference $HEAD_POD -- cat /tmp/deploy_llm.py > backup-deploy.py
```

---

## Cost Optimization

### Use Preemptible GPU Nodes

```bash
gcloud container node-pools create gpu-pool-preemptible \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --machine-type=n1-standard-4 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --preemptible \
  --num-nodes=1 \
  --node-taints=nvidia.com/gpu=present:NoSchedule
```

### Scale to Zero When Idle

```yaml
# Set minReplicas to 0
workerGroupSpecs:
- groupName: gpu-workers
  minReplicas: 0  # Scale down to 0 when no requests
  maxReplicas: 3
```

### Use Spot VMs

```bash
gcloud container node-pools create gpu-pool-spot \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --spot \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=3
```

---

## Cleanup

```bash
# Delete Ray cluster
kubectl delete raycluster -n llm-inference ray-cluster-llm

# Delete namespace
kubectl delete namespace llm-inference

# Delete GKE cluster
gcloud container clusters delete $CLUSTER_NAME --region=$REGION
```

---

## Troubleshooting

### Model Won't Load - Out of Memory

**Solution:** Use smaller model or 8-bit quantization

```python
quantization_config = BitsAndBytesConfig(load_in_8bit=True)
```

### Slow Inference

**Check:**
- GPU utilization: `nvidia-smi`
- Batch size: Increase for throughput
- Model precision: Use float16

### Pod Stuck Pending

**Check:**
```bash
kubectl describe pod -n llm-inference <pod-name>
```

**Common fixes:**
- Add GPU quota to project
- Check node pool size
- Verify tolerations match taints

---

## Model Comparison

| Model | Parameters | Memory (8-bit) | Speed (T4) | Quality |
|-------|-----------|----------------|------------|---------|
| GPT-2 Large | 774M | ~2GB | Fast | Basic |
| GPT-J-6B | 6B | ~12GB | Medium | Good |
| Llama-2-7B | 7B | ~14GB | Medium | Very Good |
| Mistral-7B | 7B | ~14GB | Medium | Excellent |
| Llama-3-8B | 8B | ~16GB | Medium | Best |

---

## Next Steps

1. ✅ Set up CI/CD pipeline
2. ✅ Add caching layer (Redis)
3. ✅ Implement rate limiting
4. ✅ Set up logging aggregation
5. ✅ Configure alerts
6. ✅ Add A/B testing
7. ✅ Implement model versioning

---

## Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Ray Serve Documentation](https://docs.ray.io/en/latest/serve/index.html)
- [Hugging Face Models](https://huggingface.co/models)
- [KubeRay Documentation](https://docs.ray.io/en/latest/cluster/kubernetes/index.html)