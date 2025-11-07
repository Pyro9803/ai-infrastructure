# GPT-OSS Model Deployment Guide

## Complete Guide to Deploying Open Source GPT Models on Kubernetes with Ray Serve

---

## Table of Contents

1. [Overview](#overview)
2. [Supported GPT-OSS Models](#supported-gpt-oss-models)
3. [Quick Start](#quick-start)
4. [Infrastructure Requirements](#infrastructure-requirements)
5. [Step-by-Step Deployment](#step-by-step-deployment)
6. [Model-Specific Configurations](#model-specific-configurations)
7. [Testing & Validation](#testing--validation)
8. [Production Optimization](#production-optimization)
9. [Troubleshooting](#troubleshooting)
10. [Cost Analysis](#cost-analysis)

---

## Overview

This guide provides a complete deployment strategy for open-source GPT models including GPT-NeoX, GPT-J, GPT-Neo, and other GPT-based architectures using Ray Serve on Kubernetes with GPU acceleration.

### What You'll Deploy

- **Multiple GPT models** with different sizes
- **Auto-scaling** based on request load
- **OpenAI-compatible API** endpoints
- **Multi-GPU support** for large models
- **Production-ready** monitoring and logging

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│          Load Balancer (Ingress/Service)                │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              Ray Head Node (Control Plane)              │
│  • Model Routing                                        │
│  • Auto-scaling Controller                              │
│  • Dashboard (8265)                                     │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┼────────────┬────────────┐
        │            │            │            │
   ┌────▼────┐  ┌───▼────┐  ┌───▼────┐  ┌───▼────┐
   │GPT-Neo  │  │GPT-J   │  │GPT-NeoX│  │Custom  │
   │1.3B-2.7B│  │6B      │  │20B     │  │GPT     │
   │(T4/L4)  │  │(L4)    │  │(A100)  │  │Models  │
   └─────────┘  └────────┘  └────────┘  └────────┘
```

---

## Supported GPT-OSS Models

### Small Models (1-3B parameters) - T4/L4 GPU

| Model | Size | Context | GPU Requirement | Use Case |
|-------|------|---------|----------------|----------|
| GPT-Neo-1.3B | 1.3B | 2048 | 1x T4 (16GB) | Text generation, chat |
| GPT-Neo-2.7B | 2.7B | 2048 | 1x L4 (24GB) | General purpose |
| Cerebras-GPT-1.3B | 1.3B | 2048 | 1x T4 (16GB) | Research, experimentation |
| OpenLLaMA-3B | 3B | 2048 | 1x L4 (24GB) | LLaMA alternative |

### Medium Models (6-7B parameters) - L4 GPU

| Model | Size | Context | GPU Requirement | Use Case |
|-------|------|---------|----------------|----------|
| GPT-J-6B | 6B | 2048 | 1x L4 (24GB) | Code, text generation |
| Cerebras-GPT-6.7B | 6.7B | 2048 | 1x L4 (24GB) | Research |
| MPT-7B | 7B | 2048/8192 | 1x L4 (24GB) | Chat, instruct |

### Large Models (13-20B parameters) - Multi-GPU

| Model | Size | Context | GPU Requirement | Use Case |
|-------|------|---------|----------------|----------|
| GPT-NeoX-20B | 20B | 2048 | 2x A100 (40GB) | Advanced reasoning |
| Cerebras-GPT-13B | 13B | 2048 | 2x L4 or 1x A100 | Research |

### Specialized Models

| Model | Size | Context | GPU Requirement | Specialty |
|-------|------|---------|----------------|-----------|
| CodeGen-6B-Multi | 6B | 2048 | 1x L4 (24GB) | Multi-language code |
| CodeGen-16B-Multi | 16B | 2048 | 2x L4 | Advanced coding |
| BLOOM-7B1 | 7.1B | 2048 | 1x L4 (24GB) | Multilingual (46 languages) |

---

## Quick Start

### Prerequisites Checklist

```bash
# 1. Kubernetes cluster with GPU support
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'

# 2. Ray Operator installed
kubectl get crd rayclusters.ray.io rayservices.ray.io

# 3. Namespace created
kubectl create namespace gpt-models

# 4. HuggingFace access (optional, for private models)
export HF_TOKEN="hf_your_token_here"
```

### 5-Minute Deployment

```bash
# Clone the repository
cd /your/deployment/directory

# Create secrets
kubectl create secret generic huggingface-secret \
  --from-literal=token=${HF_TOKEN} \
  -n gpt-models

# Deploy GPT-J-6B (example)
kubectl apply -f gpt-models/gpt-j-6b-configmap.yaml
kubectl apply -f gpt-models/ray-service-gpt.yaml

# Wait for deployment
kubectl wait --for=condition=ready rayservice/gpt-serving -n gpt-models --timeout=600s

# Test
kubectl port-forward -n gpt-models svc/gpt-serving-serve-svc 8000:8000

curl -X POST http://localhost:8000/gpt-j-6b/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-j-6b",
    "prompt": "Once upon a time",
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

---

## Infrastructure Requirements

### 1. Kubernetes Cluster Setup

#### Required Components

```bash
# Install NVIDIA GPU Operator (if not installed)
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
helm install --wait --generate-name \
  -n gpu-operator --create-namespace \
  nvidia/gpu-operator

# Install Ray Operator
kubectl create -k "github.com/ray-project/kuberay/ray-operator/config/default?ref=v1.0.0"

# Verify
kubectl get pods -n gpu-operator
kubectl get crd | grep ray
```

#### Node Pools Configuration

**Small Model Pool (T4 GPUs)**
```bash
# GKE Example
gcloud container node-pools create gpt-small-pool \
  --cluster=your-cluster \
  --zone=us-central1-a \
  --machine-type=n1-standard-8 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --num-nodes=0 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=5 \
  --disk-size=200 \
  --disk-type=pd-ssd \
  --node-taints=nvidia.com/gpu=t4:NoSchedule \
  --node-labels=gpu-type=t4,workload=gpt-small

# AWS EKS Example
eksctl create nodegroup \
  --cluster=your-cluster \
  --name=gpt-small-pool \
  --node-type=g4dn.2xlarge \
  --nodes=0 \
  --nodes-min=0 \
  --nodes-max=5 \
  --node-labels=gpu-type=t4,workload=gpt-small \
  --node-taints=nvidia.com/gpu=t4:NoSchedule
```

**Medium Model Pool (L4 GPUs)**
```bash
# GKE Example
gcloud container node-pools create gpt-medium-pool \
  --cluster=your-cluster \
  --zone=us-central1-a \
  --machine-type=g2-standard-12 \
  --accelerator=type=nvidia-l4,count=1 \
  --num-nodes=0 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=10 \
  --disk-size=300 \
  --disk-type=pd-ssd \
  --node-taints=nvidia.com/gpu=l4:NoSchedule \
  --node-labels=gpu-type=l4,workload=gpt-medium
```

**Large Model Pool (A100 GPUs)**
```bash
# GKE Example
gcloud container node-pools create gpt-large-pool \
  --cluster=your-cluster \
  --zone=us-central1-a \
  --machine-type=a2-highgpu-2g \
  --accelerator=type=nvidia-tesla-a100,count=2 \
  --num-nodes=0 \
  --enable-autoscaling \
  --min-nodes=0 \
  --max-nodes=3 \
  --disk-size=500 \
  --disk-type=pd-ssd \
  --node-taints=nvidia.com/gpu=a100:NoSchedule \
  --node-labels=gpu-type=a100,workload=gpt-large
```

### 2. Storage Configuration

```yaml
# Persistent Volume for model caching (optional but recommended)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gpt-model-cache
  namespace: gpt-models
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Gi  # Adjust based on number of models
  storageClassName: fast-ssd  # Use fast storage for model loading
```

---

## Step-by-Step Deployment

### Step 1: Create Namespace and Secrets

```bash
# Create namespace
kubectl create namespace gpt-models

# Create HuggingFace secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: huggingface-secret
  namespace: gpt-models
type: Opaque
stringData:
  token: "${HF_TOKEN}"
EOF

# Verify
kubectl get secrets -n gpt-models
```

### Step 2: Create Model ConfigMaps

**File**: `gpt-models-configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gpt-models-config
  namespace: gpt-models
data:
  # GPT-Neo-1.3B Configuration
  gpt-neo-1.3b.yaml: |
    model_loading_config:
      model_id: "gpt-neo-1.3b"
      model_source: "EleutherAI/gpt-neo-1.3B"
    deployment_config:
      name: "EleutherAI/gpt-neo-1.3B"
      ray_actor_options:
        num_cpus: 6
        resources:
          small-gpu-workers: 1
      autoscaling_config:
        min_replicas: 1
        max_replicas: 5
        target_ongoing_requests: 50
      max_ongoing_requests: 100
    engine_kwargs:
      tensor_parallel_size: 1
      dtype: "float16"
      gpu_memory_utilization: 0.85
      max_model_len: 2048
      enforce_eager: false
      max_num_seqs: 32
      max_num_batched_tokens: 4096
      trust_remote_code: false
    runtime_env:
      env_vars:
        VLLM_USE_V1: "0"
        TRANSFORMERS_CACHE: "/tmp/transformers_cache"

  # GPT-Neo-2.7B Configuration
  gpt-neo-2.7b.yaml: |
    model_loading_config:
      model_id: "gpt-neo-2.7b"
      model_source: "EleutherAI/gpt-neo-2.7B"
    deployment_config:
      name: "EleutherAI/gpt-neo-2.7B"
      ray_actor_options:
        num_cpus: 10
        resources:
          medium-gpu-workers: 1
      autoscaling_config:
        min_replicas: 1
        max_replicas: 3
        target_ongoing_requests: 40
      max_ongoing_requests: 80
    engine_kwargs:
      tensor_parallel_size: 1
      dtype: "float16"
      gpu_memory_utilization: 0.90
      max_model_len: 2048
      enforce_eager: false
      max_num_seqs: 24
      max_num_batched_tokens: 4096
      trust_remote_code: false
    runtime_env:
      env_vars:
        VLLM_USE_V1: "0"
        TRANSFORMERS_CACHE: "/tmp/transformers_cache"

  # GPT-J-6B Configuration
  gpt-j-6b.yaml: |
    model_loading_config:
      model_id: "gpt-j-6b"
      model_source: "EleutherAI/gpt-j-6b"
    deployment_config:
      name: "EleutherAI/gpt-j-6b"
      ray_actor_options:
        num_cpus: 10
        resources:
          medium-gpu-workers: 1
      autoscaling_config:
        min_replicas: 1
        max_replicas: 5
        target_ongoing_requests: 30
      max_ongoing_requests: 60
    engine_kwargs:
      tensor_parallel_size: 1
      dtype: "float16"
      gpu_memory_utilization: 0.92
      max_model_len: 2048
      enforce_eager: false
      max_num_seqs: 16
      max_num_batched_tokens: 4096
      trust_remote_code: false
    runtime_env:
      env_vars:
        VLLM_USE_V1: "0"
        TRANSFORMERS_CACHE: "/tmp/transformers_cache"

  # GPT-NeoX-20B Configuration
  gpt-neox-20b.yaml: |
    model_loading_config:
      model_id: "gpt-neox-20b"
      model_source: "EleutherAI/gpt-neox-20b"
    deployment_config:
      name: "EleutherAI/gpt-neox-20b"
      ray_actor_options:
        num_cpus: 24
        resources:
          large-gpu-workers: 1
      autoscaling_config:
        min_replicas: 1
        max_replicas: 2
        target_ongoing_requests: 20
      max_ongoing_requests: 40
    engine_kwargs:
      tensor_parallel_size: 2  # 2 GPUs
      dtype: "float16"
      gpu_memory_utilization: 0.95
      max_model_len: 2048
      enforce_eager: false
      max_num_seqs: 8
      max_num_batched_tokens: 2048
      trust_remote_code: false
    runtime_env:
      env_vars:
        VLLM_USE_V1: "0"
        TRANSFORMERS_CACHE: "/tmp/transformers_cache"

  # CodeGen-6B-Multi Configuration
  codegen-6b-multi.yaml: |
    model_loading_config:
      model_id: "codegen-6b-multi"
      model_source: "Salesforce/codegen-6B-multi"
    deployment_config:
      name: "Salesforce/codegen-6B-multi"
      ray_actor_options:
        num_cpus: 10
        resources:
          medium-gpu-workers: 1
      autoscaling_config:
        min_replicas: 1
        max_replicas: 3
        target_ongoing_requests: 25
      max_ongoing_requests: 50
    engine_kwargs:
      tensor_parallel_size: 1
      dtype: "float16"
      gpu_memory_utilization: 0.90
      max_model_len: 2048
      enforce_eager: false
      max_num_seqs: 16
      max_num_batched_tokens: 4096
      trust_remote_code: true
    runtime_env:
      env_vars:
        VLLM_USE_V1: "0"
        TRANSFORMERS_CACHE: "/tmp/transformers_cache"

  # MPT-7B Configuration
  mpt-7b.yaml: |
    model_loading_config:
      model_id: "mpt-7b"
      model_source: "mosaicml/mpt-7b"
    deployment_config:
      name: "mosaicml/mpt-7b"
      ray_actor_options:
        num_cpus: 10
        resources:
          medium-gpu-workers: 1
      autoscaling_config:
        min_replicas: 1
        max_replicas: 3
        target_ongoing_requests: 30
      max_ongoing_requests: 60
    engine_kwargs:
      tensor_parallel_size: 1
      dtype: "bfloat16"
      gpu_memory_utilization: 0.90
      max_model_len: 2048
      enforce_eager: false
      max_num_seqs: 20
      max_num_batched_tokens: 4096
      trust_remote_code: true
    runtime_env:
      env_vars:
        VLLM_USE_V1: "0"
        TRANSFORMERS_CACHE: "/tmp/transformers_cache"

  # BLOOM-7B1 Configuration
  bloom-7b1.yaml: |
    model_loading_config:
      model_id: "bloom-7b1"
      model_source: "bigscience/bloom-7b1"
    deployment_config:
      name: "bigscience/bloom-7b1"
      ray_actor_options:
        num_cpus: 10
        resources:
          medium-gpu-workers: 1
      autoscaling_config:
        min_replicas: 1
        max_replicas: 3
        target_ongoing_requests: 30
      max_ongoing_requests: 60
    engine_kwargs:
      tensor_parallel_size: 1
      dtype: "bfloat16"
      gpu_memory_utilization: 0.90
      max_model_len: 2048
      enforce_eager: false
      max_num_seqs: 20
      max_num_batched_tokens: 4096
      trust_remote_code: false
    runtime_env:
      env_vars:
        VLLM_USE_V1: "0"
        TRANSFORMERS_CACHE: "/tmp/transformers_cache"
```

Apply the ConfigMap:

```bash
kubectl apply -f gpt-models-configmap.yaml
```

### Step 3: Create RayService Deployment

**File**: `ray-service-gpt.yaml`

```yaml
apiVersion: ray.io/v1
kind: RayService
metadata:
  name: gpt-serving
  namespace: gpt-models
spec:
  serviceUnhealthySecondThreshold: 1200  # 20 minutes (large models take time)
  deploymentUnhealthySecondThreshold: 600  # 10 minutes
  
  serveConfigV2: |
    applications:
    # GPT-Neo Models
    - name: "gpt-neo-1.3b-app"
      import_path: "ray.serve.llm:build_openai_app"
      route_prefix: "/gpt-neo-1.3b"
      args:
        llm_configs:
          - models/gpt-neo-1.3b.yaml
    
    - name: "gpt-neo-2.7b-app"
      import_path: "ray.serve.llm:build_openai_app"
      route_prefix: "/gpt-neo-2.7b"
      args:
        llm_configs:
          - models/gpt-neo-2.7b.yaml
    
    # GPT-J Model
    - name: "gpt-j-6b-app"
      import_path: "ray.serve.llm:build_openai_app"
      route_prefix: "/gpt-j-6b"
      args:
        llm_configs:
          - models/gpt-j-6b.yaml
    
    # GPT-NeoX Model (Large)
    - name: "gpt-neox-20b-app"
      import_path: "ray.serve.llm:build_openai_app"
      route_prefix: "/gpt-neox-20b"
      args:
        llm_configs:
          - models/gpt-neox-20b.yaml
    
    # Code Generation Models
    - name: "codegen-6b-multi-app"
      import_path: "ray.serve.llm:build_openai_app"
      route_prefix: "/codegen-6b-multi"
      args:
        llm_configs:
          - models/codegen-6b-multi.yaml
    
    # MPT Model
    - name: "mpt-7b-app"
      import_path: "ray.serve.llm:build_openai_app"
      route_prefix: "/mpt-7b"
      args:
        llm_configs:
          - models/mpt-7b.yaml
    
    # BLOOM Model
    - name: "bloom-7b1-app"
      import_path: "ray.serve.llm:build_openai_app"
      route_prefix: "/bloom-7b1"
      args:
        llm_configs:
          - models/bloom-7b1.yaml
  
  rayClusterConfig:
    rayVersion: '2.49.1'
    enableInTreeAutoscaling: true
    
    # Head Node Configuration
    headGroupSpec:
      serviceType: ClusterIP
      rayStartParams:
        dashboard-host: '0.0.0.0'
        dashboard-port: '8265'
        num-gpus: '0'
        object-store-memory: '8589934592'  # 8GB
      
      template:
        spec:
          containers:
          - name: ray-head
            image: rayproject/ray-llm:2.49.1-py311-cu128
            resources:
              limits:
                cpu: 12
                memory: 64Gi
              requests:
                cpu: 8
                memory: 48Gi
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
              value: "2000"
            - name: RAY_SERVE_MULTIPLEXED_MODEL_LOADING
              value: "0"
            - name: PYTHONPATH
              value: "/home/ray"
            - name: HF_HOME
              value: "/tmp/huggingface"
            volumeMounts:
            - mountPath: /home/ray/models
              name: model-config
          volumes:
          - name: model-config
            configMap:
              name: gpt-models-config
          nodeSelector:
            workload: control-plane
    
    # Worker Groups
    workerGroupSpecs:
    
    # Small GPU Workers (T4) - for GPT-Neo-1.3B
    - groupName: small-gpu-workers
      replicas: 1
      minReplicas: 0
      maxReplicas: 5
      rayStartParams:
        num-gpus: '1'
        object-store-memory: '10737418240'  # 10GB
        resources: '"{\"small-gpu-workers\": 1}"'
      template:
        spec:
          containers:
          - name: ray-worker
            image: rayproject/ray-llm:2.49.1-py311-cu128
            resources:
              limits:
                cpu: 8
                memory: "28Gi"
                nvidia.com/gpu: 1
              requests:
                cpu: 6
                memory: "20Gi"
                nvidia.com/gpu: 1
            env:
            - name: PYTORCH_CUDA_ALLOC_CONF
              value: "max_split_size_mb:512"
            - name: TOKENIZERS_PARALLELISM
              value: "false"
            - name: HF_HOME
              value: "/tmp/huggingface"
            - name: TRANSFORMERS_CACHE
              value: "/tmp/transformers_cache"
            - name: HF_TOKEN
              valueFrom:
                secretKeyRef:
                  name: huggingface-secret
                  key: token
                  optional: true
            volumeMounts:
            - mountPath: /home/ray/models
              name: model-config
          volumes:
          - name: model-config
            configMap:
              name: gpt-models-config
          tolerations:
          - key: nvidia.com/gpu
            operator: Equal
            value: t4
            effect: NoSchedule
          nodeSelector:
            gpu-type: t4
    
    # Medium GPU Workers (L4) - for GPT-Neo-2.7B, GPT-J-6B, CodeGen, MPT, BLOOM
    - groupName: medium-gpu-workers
      replicas: 2
      minReplicas: 0
      maxReplicas: 10
      rayStartParams:
        num-gpus: '1'
        object-store-memory: '42949672960'  # 40GB
        resources: '"{\"medium-gpu-workers\": 1}"'
      template:
        spec:
          containers:
          - name: ray-worker
            image: rayproject/ray-llm:2.49.1-py311-cu128
            resources:
              limits:
                cpu: 12
                memory: "45Gi"
                nvidia.com/gpu: 1
              requests:
                cpu: 8
                memory: "32Gi"
                nvidia.com/gpu: 1
            env:
            - name: PYTORCH_CUDA_ALLOC_CONF
              value: "max_split_size_mb:512"
            - name: TOKENIZERS_PARALLELISM
              value: "false"
            - name: HF_HOME
              value: "/tmp/huggingface"
            - name: TRANSFORMERS_CACHE
              value: "/tmp/transformers_cache"
            - name: HF_TOKEN
              valueFrom:
                secretKeyRef:
                  name: huggingface-secret
                  key: token
                  optional: true
            volumeMounts:
            - mountPath: /home/ray/models
              name: model-config
          volumes:
          - name: model-config
            configMap:
              name: gpt-models-config
          tolerations:
          - key: nvidia.com/gpu
            operator: Equal
            value: l4
            effect: NoSchedule
          nodeSelector:
            gpu-type: l4
    
    # Large GPU Workers (2x A100) - for GPT-NeoX-20B
    - groupName: large-gpu-workers
      replicas: 1
      minReplicas: 0
      maxReplicas: 3
      rayStartParams:
        num-gpus: '2'
        object-store-memory: '85899345920'  # 80GB
        resources: '"{\"large-gpu-workers\": 1}"'
      template:
        spec:
          containers:
          - name: ray-worker
            image: rayproject/ray-llm:2.49.1-py311-cu128
            resources:
              limits:
                cpu: 24
                memory: "180Gi"
                nvidia.com/gpu: 2
              requests:
                cpu: 16
                memory: "120Gi"
                nvidia.com/gpu: 2
            env:
            - name: PYTORCH_CUDA_ALLOC_CONF
              value: "max_split_size_mb:1024"
            - name: CUDA_VISIBLE_DEVICES
              value: "0,1"
            - name: TOKENIZERS_PARALLELISM
              value: "false"
            - name: HF_HOME
              value: "/tmp/huggingface"
            - name: TRANSFORMERS_CACHE
              value: "/tmp/transformers_cache"
            - name: HF_TOKEN
              valueFrom:
                secretKeyRef:
                  name: huggingface-secret
                  key: token
                  optional: true
            volumeMounts:
            - mountPath: /home/ray/models
              name: model-config
          volumes:
          - name: model-config
            configMap:
              name: gpt-models-config
          tolerations:
          - key: nvidia.com/gpu
            operator: Equal
            value: a100
            effect: NoSchedule
          nodeSelector:
            gpu-type: a100
```

Apply the RayService:

```bash
kubectl apply -f ray-service-gpt.yaml
```

### Step 4: Create Deployment Script

**File**: `deploy-gpt-models.sh`

```bash
#!/bin/bash
set -e

# Configuration
NAMESPACE="gpt-models"
HF_TOKEN="${HF_TOKEN:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  GPT-OSS Models Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Create namespace
echo -e "${YELLOW}[1/6] Creating namespace...${NC}"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Step 2: Create secrets
echo -e "${YELLOW}[2/6] Creating secrets...${NC}"
if [ -n "$HF_TOKEN" ]; then
  kubectl create secret generic huggingface-secret \
    --from-literal=token=${HF_TOKEN} \
    -n ${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -
  echo -e "${GREEN}✓ HuggingFace secret created${NC}"
else
  echo -e "${YELLOW}⚠ HF_TOKEN not set, skipping secret creation${NC}"
fi

# Step 3: Apply ConfigMaps
echo -e "${YELLOW}[3/6] Applying model configurations...${NC}"
kubectl apply -f gpt-models-configmap.yaml -n ${NAMESPACE}
echo -e "${GREEN}✓ ConfigMaps applied${NC}"

# Step 4: Deploy RayService
echo -e "${YELLOW}[4/6] Deploying RayService...${NC}"
kubectl apply -f ray-service-gpt.yaml -n ${NAMESPACE}
echo -e "${GREEN}✓ RayService deployed${NC}"

# Step 5: Wait for deployment
echo -e "${YELLOW}[5/6] Waiting for RayService to be ready (this may take 10-15 minutes)...${NC}"
kubectl wait --for=condition=ready rayservice/gpt-serving -n ${NAMESPACE} --timeout=1200s || {
  echo -e "${RED}✗ Deployment timeout. Checking status...${NC}"
  kubectl describe rayservice/gpt-serving -n ${NAMESPACE}
  kubectl get pods -n ${NAMESPACE}
  exit 1
}

# Step 6: Show deployment info
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Successful!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Deployed Models:${NC}"
echo "  • GPT-Neo-1.3B  → /gpt-neo-1.3b"
echo "  • GPT-Neo-2.7B  → /gpt-neo-2.7b"
echo "  • GPT-J-6B      → /gpt-j-6b"
echo "  • GPT-NeoX-20B  → /gpt-neox-20b"
echo "  • CodeGen-6B    → /codegen-6b-multi"
echo "  • MPT-7B        → /mpt-7b"
echo "  • BLOOM-7B1     → /bloom-7b1"
echo ""
echo -e "${YELLOW}Access Instructions:${NC}"
echo ""
echo "1. Port-forward the service:"
echo "   kubectl port-forward -n ${NAMESPACE} svc/gpt-serving-serve-svc 8000:8000"
echo ""
echo "2. Access Ray Dashboard:"
echo "   kubectl port-forward -n ${NAMESPACE} svc/gpt-serving-head-svc 8265:8265"
echo "   Open: http://localhost:8265"
echo ""
echo "3. Test a model:"
cat <<'EOFTEST'
   curl -X POST http://localhost:8000/gpt-j-6b/v1/completions \
     -H "Content-Type: application/json" \
     -d '{
       "model": "gpt-j-6b",
       "prompt": "def fibonacci(n):",
       "max_tokens": 100,
       "temperature": 0.7
     }'
EOFTEST
echo ""
echo -e "${YELLOW}Monitor Deployment:${NC}"
echo "   kubectl get pods -n ${NAMESPACE} -w"
echo ""
echo -e "${GREEN}========================================${NC}"
```

Make it executable and run:

```bash
chmod +x deploy-gpt-models.sh
./deploy-gpt-models.sh
```

---

## Model-Specific Configurations

### GPT-Neo Series (1.3B, 2.7B)

**Best for**: General text generation, creative writing, Q&A

```yaml
# Optimized settings
engine_kwargs:
  dtype: "float16"  # Fast inference
  gpu_memory_utilization: 0.85
  max_num_seqs: 32  # High throughput
  max_model_len: 2048
```

**Use case example**:
```python
# Creative writing
prompt = "Write a short story about a robot learning to paint:"

# Code completion
prompt = "def merge_sort(arr):\n    # Implementation:"
```

### GPT-J-6B

**Best for**: Code generation, detailed text, reasoning

```yaml
# Optimized for quality
engine_kwargs:
  dtype: "float16"
  gpu_memory_utilization: 0.92  # Uses more VRAM
  max_num_seqs: 16
  temperature: 0.7  # Balanced creativity
```

**Use case example**:
```python
# Code generation
prompt = """
# Function to calculate the factorial of a number
def factorial(n):
"""

# Explanation
prompt = "Explain quantum computing in simple terms:"
```

### GPT-NeoX-20B

**Best for**: Complex reasoning, research, detailed analysis

```yaml
# Multi-GPU configuration
engine_kwargs:
  tensor_parallel_size: 2  # 2 GPUs required
  dtype: "float16"
  gpu_memory_utilization: 0.95
  max_num_seqs: 8  # Lower for quality
```

**Use case example**:
```python
# Complex reasoning
prompt = """
Analyze the following argument and identify any logical fallacies:
"Everyone I know loves this product, so it must be the best on the market."
"""

# Research assistance
prompt = "Compare and contrast supervised and unsupervised learning algorithms:"
```

### CodeGen-6B-Multi

**Best for**: Multi-language code generation

```yaml
# Code-optimized settings
engine_kwargs:
  dtype: "float16"
  max_model_len: 2048
  trust_remote_code: true  # Required for CodeGen
  temperature: 0.2  # Lower for more deterministic code
```

**Supported languages**: Python, Java, JavaScript, Go, C++, Rust

**Use case example**:
```python
# Python
prompt = "# Function to implement binary search\ndef binary_search(arr, target):"

# JavaScript
prompt = "// React component for user authentication\nfunction AuthForm() {"

# Go
prompt = "// HTTP server with middleware\nfunc main() {"
```

### MPT-7B

**Best for**: Long context tasks, chat

```yaml
# Extended context
engine_kwargs:
  max_model_len: 8192  # Can go up to 65k with MPT-7B-StoryWriter
  dtype: "bfloat16"  # Better numerical stability
  trust_remote_code: true
```

### BLOOM-7B1

**Best for**: Multilingual tasks (46 languages)

```yaml
# Multilingual settings
engine_kwargs:
  dtype: "bfloat16"
  max_model_len: 2048
  # Supports: English, French, Spanish, Arabic, Chinese, etc.
```

---

## Testing & Validation

### Health Check Script

**File**: `test-gpt-models.sh`

```bash
#!/bin/bash

ENDPOINT="http://localhost:8000"

# Test GPT-Neo-1.3B
echo "Testing GPT-Neo-1.3B..."
curl -s -X POST ${ENDPOINT}/gpt-neo-1.3b/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-neo-1.3b",
    "prompt": "The future of AI is",
    "max_tokens": 50
  }' | jq '.choices[0].text'

# Test GPT-J-6B
echo -e "\nTesting GPT-J-6B..."
curl -s -X POST ${ENDPOINT}/gpt-j-6b/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-j-6b",
    "prompt": "def hello_world():",
    "max_tokens": 50
  }' | jq '.choices[0].text'

# Test CodeGen-6B
echo -e "\nTesting CodeGen-6B-Multi..."
curl -s -X POST ${ENDPOINT}/codegen-6b-multi/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "codegen-6b-multi",
    "prompt": "// JavaScript async function\nasync function fetchData() {",
    "max_tokens": 100,
    "temperature": 0.2
  }' | jq '.choices[0].text'

echo -e "\n✅ All tests completed!"
```

### OpenAI Python Client Example

```python
from openai import OpenAI

# Initialize client
client = OpenAI(
    base_url="http://localhost:8000/gpt-j-6b/v1",
    api_key="dummy-key"  # Not required for local deployment
)

# Text completion
response = client.completions.create(
    model="gpt-j-6b",
    prompt="Write a Python function to reverse a string:",
    max_tokens=150,
    temperature=0.7,
    top_p=0.95
)

print(response.choices[0].text)

# Chat-style (for instruct models)
response = client.chat.completions.create(
    model="gpt-j-6b",
    messages=[
        {"role": "system", "content": "You are a helpful coding assistant."},
        {"role": "user", "content": "Explain list comprehensions in Python"}
    ],
    max_tokens=200
)

print(response.choices[0].message.content)
```

### Load Testing

```bash
# Install hey (HTTP load generator)
# https://github.com/rakyll/hey

# Load test GPT-Neo-1.3B (100 requests, 10 concurrent)
hey -n 100 -c 10 -m POST \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-neo-1.3b","prompt":"Hello","max_tokens":10}' \
  http://localhost:8000/gpt-neo-1.3b/v1/completions

# Monitor during load test
kubectl top pods -n gpt-models
```

---

## Production Optimization

### 1. Horizontal Pod Autoscaling (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: gpt-j-hpa
  namespace: gpt-models
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: gpt-j-deployment
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### 2. Model Caching

```yaml
# Add persistent volume for model caching
volumeMounts:
- name: model-cache
  mountPath: /root/.cache/huggingface
volumes:
- name: model-cache
  persistentVolumeClaim:
    claimName: gpt-model-cache
```

### 3. Request Batching

```yaml
# Optimize for throughput
engine_kwargs:
  max_num_seqs: 32  # Increase batch size
  max_num_batched_tokens: 8192  # Higher throughput
```

### 4. Ingress Configuration

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gpt-ingress
  namespace: gpt-models
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
spec:
  tls:
  - hosts:
    - gpt-api.yourdomain.com
    secretName: gpt-tls-secret
  rules:
  - host: gpt-api.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gpt-serving-serve-svc
            port:
              number: 8000
```

### 5. Monitoring with Prometheus

```yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: ray-metrics
  namespace: gpt-models
spec:
  selector:
    matchLabels:
      app: ray
  endpoints:
  - port: metrics
    interval: 30s
```

---

## Troubleshooting

### Common Issues

#### 1. Model Loading Timeout

**Symptom**: Pods stuck in "Loading model..." state

**Solution**:
```yaml
# Increase timeout in RayService
spec:
  deploymentUnhealthySecondThreshold: 1800  # 30 minutes for large models
```

#### 2. CUDA Out of Memory

**Symptom**: `CUDA out of memory` errors in logs

**Solution**:
```yaml
# Reduce GPU memory utilization or batch size
engine_kwargs:
  gpu_memory_utilization: 0.75  # Lower from 0.90
  max_num_seqs: 8  # Lower from 16
```

#### 3. Slow Inference

**Symptom**: High latency (>5 seconds for small prompts)

**Solutions**:
```yaml
# 1. Enable CUDA graphs
engine_kwargs:
  enforce_eager: false

# 2. Reduce batch size for lower latency
  max_num_seqs: 1  # No batching

# 3. Use smaller precision
  dtype: "float16"  # Instead of bfloat16
```

#### 4. Model Download Failures

**Symptom**: `Failed to download model from HuggingFace`

**Solutions**:
```bash
# 1. Check HuggingFace status
curl -I https://huggingface.co

# 2. Pre-download models to persistent volume
kubectl run -it --rm model-downloader --image=python:3.11 \
  --env HF_TOKEN=${HF_TOKEN} -- bash

# Inside pod:
pip install huggingface_hub
python -c "from huggingface_hub import snapshot_download; snapshot_download('EleutherAI/gpt-j-6b')"
```

#### 5. Worker Pods Not Scheduling

**Symptom**: Pods in "Pending" state

**Check**:
```bash
# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check GPU availability
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'

# Check taints and tolerations
kubectl describe pod <pod-name> -n gpt-models | grep -A 5 "Tolerations"
```

### Debug Commands

```bash
# Check RayService status
kubectl describe rayservice gpt-serving -n gpt-models

# View head node logs
kubectl logs -n gpt-models -l ray.io/node-type=head --tail=100 -f

# View worker logs
kubectl logs -n gpt-models -l ray.io/node-type=worker --tail=100 -f

# Exec into head node
kubectl exec -it -n gpt-models $(kubectl get pods -n gpt-models -l ray.io/node-type=head -o name) -- bash

# Check Ray cluster status
ray status

# Check GPU utilization
nvidia-smi

# View model loading progress
tail -f /tmp/ray/session_latest/logs/serve/*
```

---

## Cost Analysis

### Monthly Cost Estimates (GCP)

#### Small Deployment (GPT-Neo-1.3B, GPT-Neo-2.7B)

| Component | Spec | Hours/Month | Cost/Month |
|-----------|------|-------------|------------|
| Head Node | n1-standard-8 (no GPU) | 730 | ~$195 |
| T4 Worker | n1-standard-8 + T4 | 730 | ~$513 |
| L4 Worker | g2-standard-12 + L4 | 730 | ~$872 |
| **Total** | | | **~$1,580** |

#### Medium Deployment (GPT-J-6B, CodeGen, MPT)

| Component | Spec | Hours/Month | Cost/Month |
|-----------|------|-------------|------------|
| Head Node | n1-standard-8 | 730 | ~$195 |
| L4 Workers (3x) | g2-standard-12 + L4 | 2,190 | ~$2,616 |
| **Total** | | | **~$2,811** |

#### Large Deployment (GPT-NeoX-20B)

| Component | Spec | Hours/Month | Cost/Month |
|-----------|------|-------------|------------|
| Head Node | n1-standard-8 | 730 | ~$195 |
| A100 Worker (2 GPUs) | a2-highgpu-2g | 730 | ~$4,380 |
| **Total** | | | **~$4,575** |

### Cost Optimization Strategies

```bash
# 1. Use Spot/Preemptible Instances (60-90% savings)
gcloud container node-pools create gpt-spot-pool \
  --spot \
  --machine-type=g2-standard-12 \
  --accelerator=type=nvidia-l4,count=1

# 2. Auto-scale to zero during off-hours
# Set minReplicas: 0 in worker groups

# 3. Use model quantization
engine_kwargs:
  quantization: "awq"  # 2-4x smaller, minimal quality loss

# 4. Share infrastructure across multiple models
# Deploy multiple models on same worker pool

# 5. Use regional vs zonal resources
# Zonal resources are typically 10-20% cheaper
```

---

## Appendix

### A. Complete Deployment Checklist

```
Pre-Deployment:
□ Kubernetes cluster created
□ GPU nodes configured
□ Ray Operator installed
□ Namespace created
□ HuggingFace token obtained (if needed)
□ Storage provisioned (optional)

Configuration:
□ Model ConfigMaps created
□ Worker groups configured for model sizes
□ Resource limits appropriate
□ Autoscaling parameters set
□ Secrets created

Deployment:
□ ConfigMaps applied
□ RayService deployed
□ Pods running without errors
□ Models loaded successfully
□ API endpoints accessible

Testing:
□ Health checks passing
□ Sample requests successful
□ Latency acceptable
□ Throughput meets requirements
□ Autoscaling tested

Production:
□ Ingress configured
□ TLS certificates installed
□ Monitoring enabled
□ Alerts configured
□ Backup/disaster recovery planned
```

### B. Model Comparison Matrix

| Model | Size | Context | Speed | Quality | Memory | Best For |
|-------|------|---------|-------|---------|--------|----------|
| GPT-Neo-1.3B | 1.3B | 2048 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | 16GB | Fast prototyping |
| GPT-Neo-2.7B | 2.7B | 2048 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 24GB | Balanced |
| GPT-J-6B | 6B | 2048 | ⭐⭐⭐ | ⭐⭐⭐⭐ | 24GB | Code, reasoning |
| GPT-NeoX-20B | 20B | 2048 | ⭐⭐ | ⭐⭐⭐⭐⭐ | 80GB | Research |
| CodeGen-6B | 6B | 2048 | ⭐⭐⭐ | ⭐⭐⭐⭐ | 24GB | Code generation |
| MPT-7B | 7B | 8192 | ⭐⭐⭐ | ⭐⭐⭐⭐ | 24GB | Long context |
| BLOOM-7B1 | 7.1B | 2048 | ⭐⭐⭐ | ⭐⭐⭐⭐ | 24GB | Multilingual |

### C. API Reference

**Completions Endpoint**:
```bash
POST /MODEL_NAME/v1/completions

# Request
{
  "model": "gpt-j-6b",
  "prompt": "Hello, world!",
  "max_tokens": 100,
  "temperature": 0.7,
  "top_p": 0.95,
  "frequency_penalty": 0.0,
  "presence_penalty": 0.0,
  "stop": ["\n\n"]
}

# Response
{
  "id": "cmpl-xxx",
  "object": "text_completion",
  "created": 1234567890,
  "model": "gpt-j-6b",
  "choices": [{
    "text": "Generated text...",
    "index": 0,
    "finish_reason": "length"
  }]
}
```

**Chat Endpoint** (for instruct models):
```bash
POST /MODEL_NAME/v1/chat/completions

# Request
{
  "model": "gpt-j-6b",
  "messages": [
    {"role": "system", "content": "You are helpful."},
    {"role": "user", "content": "Hello!"}
  ],
  "max_tokens": 100
}
```

### D. Additional Resources

- **EleutherAI Models**: https://www.eleuther.ai/
- **Ray Serve Documentation**: https://docs.ray.io/en/latest/serve/
- **vLLM Documentation**: https://docs.vllm.ai/
- **HuggingFace Hub**: https://huggingface.co/models
- **KubeRay**: https://docs.ray.io/en/latest/cluster/kubernetes/

---

**Document Version**: 1.0  
**Last Updated**: November 2025  
**Compatibility**: Ray 2.49.1, Kubernetes 1.24+, CUDA 12.0+

**Support**: For issues or questions, please refer to:
- Ray Community: https://discuss.ray.io/
- GitHub Issues: https://github.com/ray-project/ray

---

## Quick Reference Commands

```bash
# Deploy
./deploy-gpt-models.sh

# Check status
kubectl get rayservice -n gpt-models
kubectl get pods -n gpt-models

# View logs
kubectl logs -n gpt-models -l ray.io/node-type=head -f

# Port forward
kubectl port-forward -n gpt-models svc/gpt-serving-serve-svc 8000:8000

# Test
curl -X POST http://localhost:8000/gpt-j-6b/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-j-6b","prompt":"Hello","max_tokens":50}'

# Scale
kubectl scale rayservice/gpt-serving --replicas=5 -n gpt-models

# Delete
kubectl delete rayservice gpt-serving -n gpt-models
kubectl delete namespace gpt-models
```
