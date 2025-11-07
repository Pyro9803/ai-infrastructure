# AI Model Deployment Guide - Ray Serve on Kubernetes

## Overview

This guide provides a complete framework for deploying Large Language Models (LLMs) using Ray Serve on Kubernetes with GPU support. The architecture supports:

- ✅ Multiple models with different sizes
- ✅ Auto-scaling based on load
- ✅ GPU resource optimization
- ✅ OpenAI-compatible API endpoints
- ✅ Multi-tier GPU architecture (T4, L4, A100)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Infrastructure Setup](#infrastructure-setup)
4. [Model Configuration](#model-configuration)
5. [Deployment Process](#deployment-process)
6. [Scaling & Optimization](#scaling--optimization)
7. [Monitoring & Troubleshooting](#monitoring--troubleshooting)
8. [Cost Optimization](#cost-optimization)

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Load Balancer / Ingress              │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              Ray Head Node (No GPU)                     │
│  - Dashboard (8265)                                     │
│  - Ray Serve Controller                                 │
│  - Request Routing                                      │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┼────────────┬────────────┐
        │            │            │            │
┌───────▼──────┐ ┌──▼──────┐ ┌──▼──────┐ ┌──▼──────┐
│ Small Models │ │ Medium  │ │  Large  │ │ XLarge  │
│   (T4 GPU)   │ │(L4 GPU) │ │(2xL4)   │ │(2xA100) │
│   0.5B-3B    │ │ 3B-7B   │ │ 7B-13B  │ │  13B+   │
└──────────────┘ └─────────┘ └─────────┘ └─────────┘
```

### Key Components

1. **Ray Head Node**: Orchestration, no GPU required
2. **Worker Groups**: GPU-enabled nodes for model inference
3. **ConfigMaps**: Model configurations stored as Kubernetes ConfigMaps
4. **RayService**: Custom Resource Definition (CRD) that manages the cluster

---

## Prerequisites

### 1. Kubernetes Cluster

- **Kubernetes Version**: 1.24+
- **GPU Nodes**: NVIDIA GPU support with device plugin installed
- **Storage**: Persistent storage for model caching (optional but recommended)
- **Networking**: LoadBalancer or Ingress controller

### 2. Required Kubernetes Resources

```bash
# Install Ray Operator
kubectl create -k "github.com/ray-project/kuberay/ray-operator/config/default?ref=v1.0.0"

# Create namespace
kubectl create namespace ai

# Verify GPU nodes
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'
```

### 3. Docker Images

- **Ray Image**: `rayproject/ray-llm:2.49.1-py311-cu128`
- Or build custom image with your dependencies

### 4. Model Access

- **HuggingFace Account** (for private models)
- **API Token** with read access
- **Storage**: Sufficient disk space for model weights

---

## Infrastructure Setup

### Step 1: Define GPU Node Pools

Create node pools based on your model requirements:

#### Small Model Pool (T4 GPUs)
```yaml
# GKE Example
gcloud container node-pools create t4-pool \
  --cluster=your-cluster \
  --machine-type=n1-standard-8 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --num-nodes=0 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=5 \
  --node-taints=nvidia.com/gpu-type=t4:NoSchedule \
  --node-labels=cloud.google.com/gke-nodepool=t4-pool
```

#### Medium Model Pool (L4 GPUs)
```yaml
gcloud container node-pools create l4-pool \
  --cluster=your-cluster \
  --machine-type=g2-standard-12 \
  --accelerator=type=nvidia-l4,count=1 \
  --num-nodes=0 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=10 \
  --node-taints=nvidia.com/gpu-type=l4:NoSchedule \
  --node-labels=cloud.google.com/gke-nodepool=l4-pool
```

#### Large Model Pool (Multi-GPU)
```yaml
gcloud container node-pools create l4-multi-pool \
  --cluster=your-cluster \
  --machine-type=g2-standard-24 \
  --accelerator=type=nvidia-l4,count=2 \
  --num-nodes=0 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=5 \
  --node-taints=nvidia.com/gpu-type=l4:NoSchedule \
  --node-labels=cloud.google.com/gke-nodepool=l4-multi-pool
```

#### XLarge Model Pool (A100)
```yaml
gcloud container node-pools create a100-pool \
  --cluster=your-cluster \
  --machine-type=a3-highgpu-2g \
  --accelerator=type=nvidia-tesla-a100-80gb,count=2 \
  --num-nodes=0 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=3 \
  --node-taints=nvidia.com/gpu-type=a100-80g:NoSchedule \
  --node-labels=cloud.google.com/gke-nodepool=a100-pool
```

### Step 2: Create Secrets

```bash
# HuggingFace Token
kubectl create secret generic huggingface-secret \
  --from-literal=token=hf_your_token_here \
  -n ai

# Or use a Kubernetes manifest
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: huggingface-secret
  namespace: ai
type: Opaque
stringData:
  token: "hf_your_token_here"
EOF
```

---

## Model Configuration

### Step 1: Create Model ConfigMap Template

Create a ConfigMap for each model family. Here's a template:

**File**: `model-family-configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: your-model-family-config
  namespace: ai
data:
  model-name.yaml: |
    model_loading_config:
      model_id: "unique-model-id"
      model_source: "huggingface-org/model-name"
    
    deployment_config:
      name: "huggingface-org/model-name"
      ray_actor_options:
        num_cpus: 10  # Adjust based on model size
        resources:
          medium-model-workers: 1  # Choose worker tier
      autoscaling_config:
        min_replicas: 1  # Minimum instances
        max_replicas: 3  # Maximum instances
        target_ongoing_requests: 85  # Scale up threshold
      max_ongoing_requests: 100  # Queue limit
    
    engine_kwargs:
      tensor_parallel_size: 1  # GPUs per instance
      dtype: "bfloat16"  # or "float16"
      gpu_memory_utilization: 0.9  # 90% GPU memory
      max_model_len: 8192  # Context window
      enforce_eager: false  # Use CUDA graphs
      max_num_seqs: 48  # Batch size
      max_num_batched_tokens: 8192
      trust_remote_code: true
      disable_custom_all_reduce: true
    
    runtime_env:
      env_vars:
        VLLM_USE_V1: "0"
        VLLM_WORKER_MULTIPROC_METHOD: "spawn"
        HUGGING_FACE_HUB_TOKEN: "${HF_TOKEN}"  # Reference secret
```

### Step 2: Configuration Guidelines

#### GPU Memory Utilization by Model Size

| Model Size | GPU Memory Utilization | Recommended GPU |
|-----------|------------------------|-----------------|
| 0.5B - 1B | 0.2 - 0.3 | T4 (16GB) |
| 1B - 3B | 0.5 - 0.7 | T4/L4 |
| 3B - 7B | 0.7 - 0.85 | L4 (24GB) |
| 7B - 13B | 0.85 - 0.9 | 2x L4 |
| 13B - 30B | 0.9 - 0.95 | 2x A100 40GB |
| 30B+ | 0.9 - 0.95 | 2x A100 80GB |

#### Tensor Parallel Configuration

```yaml
# Single GPU (up to 7B models)
tensor_parallel_size: 1

# 2 GPUs (7B-30B models)
tensor_parallel_size: 2

# 4 GPUs (30B-70B models)
tensor_parallel_size: 4

# 8 GPUs (70B+ models)
tensor_parallel_size: 8
```

#### Context Length by Use Case

```yaml
# Chat/Instruct models
max_model_len: 2048  # or 4096

# Code generation
max_model_len: 8192  # or 16384

# Document processing
max_model_len: 32768  # or 65536

# Long context
max_model_len: 131072  # if model supports
```

#### Batch Size Optimization

```yaml
# Small models (1B-3B)
max_num_seqs: 64
max_num_batched_tokens: 8192

# Medium models (3B-7B)
max_num_seqs: 48
max_num_batched_tokens: 16384

# Large models (7B-13B)
max_num_seqs: 24
max_num_batched_tokens: 32768

# Very large models (13B+)
max_num_seqs: 16
max_num_batched_tokens: 16384
```

---

## Deployment Process

### Step 1: Create RayService Manifest

**File**: `ray-service.yaml`

```yaml
apiVersion: ray.io/v1
kind: RayService
metadata:
  name: llm-serving
  namespace: ai
spec:
  serviceUnhealthySecondThreshold: 900  # 15 minutes
  deploymentUnhealthySecondThreshold: 300  # 5 minutes
  
  serveConfigV2: |
    applications:
    # Define your models here
    - name: "model-1-app"
      import_path: "ray.serve.llm:build_openai_app"
      route_prefix: "/model-1"
      args:
        llm_configs:
          - models/model-1.yaml
    
    - name: "model-2-app"
      import_path: "ray.serve.llm:build_openai_app"
      route_prefix: "/model-2"
      args:
        llm_configs:
          - models/model-2.yaml
  
  rayClusterConfig:
    rayVersion: '2.49.1'
    enableInTreeAutoscaling: true
    
    # Head Node Configuration
    headGroupSpec:
      serviceType: ClusterIP
      rayStartParams:
        dashboard-host: '0.0.0.0'
        dashboard-port: '8265'
        num-gpus: '0'  # Head node doesn't need GPU
        object-store-memory: '4294967296'  # 4GB
      
      template:
        spec:
          containers:
          - name: ray-head
            image: rayproject/ray-llm:2.49.1-py311-cu128
            resources:
              limits:
                cpu: 10
                memory: 48Gi
              requests:
                cpu: 8
                memory: 32Gi
            ports:
            - containerPort: 6379
              name: gcs-server
            - containerPort: 8265
              name: dashboard
            - containerPort: 10001
              name: client
            - containerPort: 8000
              name: serve
            env:
            - name: RAY_SERVE_ENABLE_EXPERIMENTAL_STREAMING
              value: "1"
            - name: RAY_SERVE_REQUEST_PROCESSING_TIMEOUT_S
              value: "1500"
            - name: PYTHONPATH
              value: "/home/ray"
            volumeMounts:
            - mountPath: /home/ray/models
              name: model-config
          volumes:
          - name: model-config
            configMap:
              name: your-model-family-config
          nodeSelector:
            cloud.google.com/gke-nodepool: app-pool  # CPU-only pool
    
    # Worker Groups
    workerGroupSpecs:
    
    # Small Model Workers (T4 GPU)
    - groupName: small-model-workers
      replicas: 1
      minReplicas: 0
      maxReplicas: 5
      rayStartParams:
        num-gpus: '1'
        object-store-memory: '8589934592'  # 8GB
        resources: '"{\"small-model-workers\": 1}"'
      template:
        spec:
          containers:
          - name: ray-worker
            image: rayproject/ray-llm:2.49.1-py311-cu128
            resources:
              limits:
                cpu: 6
                memory: "24Gi"
                nvidia.com/gpu: 1
              requests:
                cpu: 4
                memory: "14Gi"
                nvidia.com/gpu: 1
            env:
            - name: PYTORCH_CUDA_ALLOC_CONF
              value: "max_split_size_mb:256"
            - name: TOKENIZERS_PARALLELISM
              value: "false"
            - name: HF_TOKEN
              valueFrom:
                secretKeyRef:
                  name: huggingface-secret
                  key: token
            volumeMounts:
            - mountPath: /home/ray/models
              name: model-config
          volumes:
          - name: model-config
            configMap:
              name: your-model-family-config
          tolerations:
          - key: nvidia.com/gpu-type
            operator: Equal
            value: t4
            effect: NoSchedule
          nodeSelector:
            cloud.google.com/gke-nodepool: t4-pool
    
    # Medium Model Workers (L4 GPU)
    - groupName: medium-model-workers
      replicas: 1
      minReplicas: 0
      maxReplicas: 10
      rayStartParams:
        num-gpus: '1'
        object-store-memory: '42949672960'  # 40GB
        resources: '"{\"medium-model-workers\": 1}"'
      template:
        spec:
          containers:
          - name: ray-worker
            image: rayproject/ray-llm:2.49.1-py311-cu128
            resources:
              limits:
                cpu: 10
                memory: "40Gi"
                nvidia.com/gpu: 1
              requests:
                cpu: 5
                memory: "30Gi"
                nvidia.com/gpu: 1
            env:
            - name: PYTORCH_CUDA_ALLOC_CONF
              value: "max_split_size_mb:256"
            - name: TOKENIZERS_PARALLELISM
              value: "false"
            - name: HF_TOKEN
              valueFrom:
                secretKeyRef:
                  name: huggingface-secret
                  key: token
            volumeMounts:
            - mountPath: /home/ray/models
              name: model-config
          volumes:
          - name: model-config
            configMap:
              name: your-model-family-config
          tolerations:
          - key: nvidia.com/gpu-type
            operator: Equal
            value: l4
            effect: NoSchedule
          nodeSelector:
            cloud.google.com/gke-nodepool: l4-pool
    
    # Large Model Workers (2x L4 GPUs)
    - groupName: large-model-workers
      replicas: 1
      minReplicas: 0
      maxReplicas: 5
      rayStartParams:
        num-gpus: '2'
        object-store-memory: '85899345920'  # 80GB
        resources: '"{\"large-model-workers\": 1}"'
      template:
        spec:
          containers:
          - name: ray-worker
            image: rayproject/ray-llm:2.49.1-py311-cu128
            resources:
              limits:
                cpu: 20
                memory: "85Gi"
                nvidia.com/gpu: 2
              requests:
                cpu: 15
                memory: "50Gi"
                nvidia.com/gpu: 2
            env:
            - name: PYTORCH_CUDA_ALLOC_CONF
              value: "max_split_size_mb:256"
            - name: TOKENIZERS_PARALLELISM
              value: "false"
            - name: HF_TOKEN
              valueFrom:
                secretKeyRef:
                  name: huggingface-secret
                  key: token
            volumeMounts:
            - mountPath: /home/ray/models
              name: model-config
          volumes:
          - name: model-config
            configMap:
              name: your-model-family-config
          tolerations:
          - key: nvidia.com/gpu-type
            operator: Equal
            value: l4
            effect: NoSchedule
          nodeSelector:
            cloud.google.com/gke-nodepool: l4-multi-pool
    
    # XLarge Model Workers (2x A100 80GB)
    - groupName: xlarge-model-workers
      replicas: 1
      minReplicas: 0
      maxReplicas: 3
      rayStartParams:
        num-gpus: '2'
        object-store-memory: '81061273600'  # 75GB
        resources: '"{\"xlarge-model-workers\": 1}"'
      template:
        spec:
          containers:
          - name: ray-worker
            image: rayproject/ray-llm:2.49.1-py311-cu128
            resources:
              limits:
                cpu: 24
                memory: "290Gi"
                nvidia.com/gpu: 2
              requests:
                cpu: 16
                memory: "100Gi"
                nvidia.com/gpu: 2
            env:
            - name: PYTORCH_CUDA_ALLOC_CONF
              value: "max_split_size_mb:512"
            - name: CUDA_VISIBLE_DEVICES
              value: "0,1"
            - name: TOKENIZERS_PARALLELISM
              value: "false"
            - name: HF_TOKEN
              valueFrom:
                secretKeyRef:
                  name: huggingface-secret
                  key: token
            volumeMounts:
            - mountPath: /home/ray/models
              name: model-config
          volumes:
          - name: model-config
            configMap:
              name: your-model-family-config
          tolerations:
          - key: nvidia.com/gpu-type
            operator: Equal
            value: a100-80g
            effect: NoSchedule
          nodeSelector:
            cloud.google.com/gke-nodepool: a100-pool
```

### Step 2: Deploy

Create a deployment script:

**File**: `deploy.sh`

```bash
#!/bin/bash
set -e

NAMESPACE="ai"
ENV=${1:-prod}  # prod, staging, or dev

echo "🚀 Deploying AI Models to ${ENV} environment..."

# Step 1: Create namespace if it doesn't exist
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Step 2: Apply secrets
echo "📝 Applying secrets..."
kubectl apply -f secrets/ -n ${NAMESPACE}

# Step 3: Apply ConfigMaps
echo "📦 Applying model configurations..."
kubectl apply -f models/ -n ${NAMESPACE}

# Step 4: Apply RayService
echo "🎯 Deploying RayService..."
kubectl apply -f ray-service-${ENV}.yaml -n ${NAMESPACE}

# Step 5: Wait for deployment
echo "⏳ Waiting for RayService to be ready..."
kubectl wait --for=condition=ready rayservice/llm-serving -n ${NAMESPACE} --timeout=600s

# Step 6: Show status
echo "✅ Deployment complete!"
echo ""
echo "Ray Dashboard:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/llm-serving-head-svc 8265:8265"
echo ""
echo "API Endpoint:"
kubectl get svc -n ${NAMESPACE} llm-serving-serve-svc

echo ""
echo "Test your models:"
echo "  curl -X POST http://<service-ip>:8000/model-1/v1/chat/completions \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"model\": \"your-model-id\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'"
```

Make it executable and run:

```bash
chmod +x deploy.sh
./deploy.sh prod
```

---

## Scaling & Optimization

### Autoscaling Configuration

#### Production Settings
```yaml
autoscaling_config:
  min_replicas: 2  # High availability
  max_replicas: 10  # Handle traffic spikes
  target_ongoing_requests: 50  # Aggressive scaling
```

#### Development Settings
```yaml
autoscaling_config:
  min_replicas: 0  # Scale to zero to save costs
  max_replicas: 2  # Limited scale
  target_ongoing_requests: 100  # Conservative scaling
```

### Performance Tuning

#### For High Throughput
```yaml
engine_kwargs:
  max_num_seqs: 64  # Large batch
  max_num_batched_tokens: 16384
  gpu_memory_utilization: 0.95  # Max GPU usage
```

#### For Low Latency
```yaml
engine_kwargs:
  max_num_seqs: 1  # No batching
  enforce_eager: true  # Faster startup
  gpu_memory_utilization: 0.7  # Reserve memory
```

#### For Memory Efficiency
```yaml
engine_kwargs:
  gpu_memory_utilization: 0.6  # Conservative
  max_num_seqs: 24  # Moderate batch
  enable_prefix_caching: true  # Cache common prompts
```

---

## Monitoring & Troubleshooting

### Access Ray Dashboard

```bash
# Port forward to Ray dashboard
kubectl port-forward -n ai svc/llm-serving-head-svc 8265:8265

# Open in browser: http://localhost:8265
```

### Check Deployment Status

```bash
# Check RayService
kubectl get rayservice -n ai

# Check pods
kubectl get pods -n ai

# Check GPU allocation
kubectl describe nodes | grep -A 5 "nvidia.com/gpu"

# View logs
kubectl logs -n ai <pod-name> --tail=100 -f
```

### Common Issues & Solutions

#### Issue: Model Loading Timeout
```yaml
# Increase timeout in RayService
spec:
  deploymentUnhealthySecondThreshold: 900  # 15 minutes
```

#### Issue: OOM (Out of Memory)
```yaml
# Reduce GPU memory utilization or batch size
engine_kwargs:
  gpu_memory_utilization: 0.7  # Lower from 0.9
  max_num_seqs: 24  # Lower from 48
```

#### Issue: Slow Autoscaling
```yaml
# Adjust scaling parameters
autoscaling_config:
  target_ongoing_requests: 30  # Lower threshold
  upscale_delay_s: 10  # Faster scale-up
  downscale_delay_s: 600  # Slower scale-down
```

#### Issue: GPU Not Detected
```bash
# Verify GPU driver on nodes
kubectl run -it --rm gpu-test --image=nvidia/cuda:12.0.0-base-ubuntu22.04 --restart=Never -- nvidia-smi

# Check device plugin
kubectl get daemonset -n kube-system nvidia-gpu-device-plugin
```

### Debugging Commands

```bash
# Exec into head node
kubectl exec -it -n ai <head-pod-name> -- bash

# Check Ray cluster status
ray status

# List Ray actors
ray list actors

# Monitor GPU usage in real-time
watch -n 1 nvidia-smi

# Check vLLM logs
tail -f /tmp/ray/session_latest/logs/serve/*
```

---

## Cost Optimization

### 1. Auto-scaling from Zero

```yaml
# Allow scaling to zero when idle
workerGroupSpecs:
- groupName: medium-model-workers
  replicas: 0  # Start with zero
  minReplicas: 0  # Can scale to zero
  maxReplicas: 5
```

### 2. Use Spot/Preemptible Instances

```bash
# GKE example with spot instances
gcloud container node-pools create l4-spot-pool \
  --cluster=your-cluster \
  --spot \
  --machine-type=g2-standard-12 \
  --accelerator=type=nvidia-l4,count=1 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=10
```

### 3. Right-size GPU Selection

| Use Case | Recommended GPU | Cost Efficiency |
|----------|----------------|-----------------|
| Small models (<3B) | T4 | ⭐⭐⭐⭐⭐ |
| Medium models (3B-7B) | L4 | ⭐⭐⭐⭐ |
| Large models (7B-13B) | 2x L4 | ⭐⭐⭐ |
| Very large (13B+) | A100 | ⭐⭐ |

### 4. Model Quantization

```yaml
# Use quantized models for cost savings
engine_kwargs:
  quantization: "awq"  # or "gptq", "squeezellm"
  dtype: "float16"  # Lower precision
```

### 5. Schedule-based Scaling

```bash
# Scale down during off-hours (example with CronJob)
kubectl create -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scale-down-night
  namespace: ai
spec:
  schedule: "0 22 * * *"  # 10 PM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: kubectl
            image: bitnami/kubectl
            command:
            - kubectl
            - scale
            - rayservice/llm-serving
            - --replicas=0
          restartPolicy: Never
EOF
```

---

## Checklist for New Deployments

### Pre-Deployment

- [ ] Kubernetes cluster with GPU support configured
- [ ] Ray Operator installed
- [ ] Namespace created (`ai`)
- [ ] Secrets configured (HuggingFace token)
- [ ] Node pools created for each GPU tier
- [ ] Model weights accessible (HuggingFace or private registry)

### Model Configuration

- [ ] Model ConfigMap created with correct:
  - [ ] `model_source` (HuggingFace path)
  - [ ] `tensor_parallel_size` (GPU count)
  - [ ] `gpu_memory_utilization` (based on model size)
  - [ ] `max_model_len` (context window)
  - [ ] `dtype` (precision)
  - [ ] Worker group selection

### RayService Configuration

- [ ] Model added to `serveConfigV2` applications
- [ ] Correct worker group specified
- [ ] Autoscaling parameters set
- [ ] Resource limits configured
- [ ] Health check timeouts appropriate

### Post-Deployment

- [ ] RayService status is `Ready`
- [ ] Pods are running without errors
- [ ] GPU allocation verified
- [ ] API endpoint accessible
- [ ] Test inference request successful
- [ ] Autoscaling tested
- [ ] Monitoring dashboard accessible

---

## Example: Complete Deployment

### Directory Structure

```
your-project/
├── deploy.sh
├── secrets/
│   └── huggingface-secret.yaml
├── models/
│   ├── small-models-configmap.yaml
│   ├── medium-models-configmap.yaml
│   └── large-models-configmap.yaml
├── ray-service-dev.yaml
├── ray-service-staging.yaml
└── ray-service-prod.yaml
```

### Quick Start Commands

```bash
# 1. Clone and setup
git clone <your-repo>
cd your-project

# 2. Update secrets
export HF_TOKEN="hf_your_token_here"
cat secrets/huggingface-secret.yaml | envsubst | kubectl apply -f -

# 3. Deploy to dev environment
./deploy.sh dev

# 4. Test
kubectl port-forward -n ai svc/llm-serving-serve-svc 8000:8000

curl -X POST http://localhost:8000/your-model/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model-id",
    "messages": [{"role": "user", "content": "Hello, how are you?"}],
    "max_tokens": 100
  }'

# 5. Monitor
kubectl port-forward -n ai svc/llm-serving-head-svc 8265:8265
# Open: http://localhost:8265

# 6. Deploy to production
./deploy.sh prod
```

---

## Additional Resources

### Documentation
- [Ray Serve Documentation](https://docs.ray.io/en/latest/serve/index.html)
- [vLLM Documentation](https://docs.vllm.ai/)
- [KubeRay Documentation](https://docs.ray.io/en/latest/cluster/kubernetes/index.html)

### Performance Tuning
- [vLLM Performance Benchmarks](https://docs.vllm.ai/en/latest/performance/benchmarks.html)
- [GPU Memory Optimization](https://docs.vllm.ai/en/latest/performance/gpu_memory.html)

### Community
- [Ray Slack](https://forms.gle/9TSdDYUgxYs8SA9e8)
- [vLLM GitHub](https://github.com/vllm-project/vllm)

---

## License & Support

This guide is based on production deployments of Falcon models. Adapt configurations based on your specific:
- Model architectures
- Infrastructure constraints
- Performance requirements
- Budget limitations

For production support, consider:
- Professional Ray/Anyscale support
- Cloud provider managed services
- DevOps team training

---

**Last Updated**: November 2025  
**Version**: 1.0  
**Compatibility**: Ray 2.49.1, Kubernetes 1.24+
