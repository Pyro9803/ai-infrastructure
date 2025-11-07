# Model Deployment Guide

This guide explains how to deploy LLM models on Kubernetes using Ray Serve and KubeRay operator.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Deployment Steps](#deployment-steps)
- [Troubleshooting](#troubleshooting)
- [Testing](#testing)

## Overview

This deployment uses:
- **Ray Serve**: For serving LLM models with autoscaling
- **KubeRay Operator**: Manages Ray clusters on Kubernetes
- **vLLM**: High-performance inference engine for LLMs
- **RayService**: Custom resource for deploying serve applications

## Prerequisites

1. **Kubernetes Cluster** with GPU nodes
   - GPU node pool with NVIDIA Tesla T4 (or compatible)
   - GPU drivers and device plugin installed
   
2. **KubeRay Operator** installed
   ```bash
   helm install kuberay-operator kuberay/kuberay-operator --version 1.0.0
   ```

3. **Namespace** for AI workloads
   ```bash
   kubectl create namespace ai
   ```

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────┐
│                     RayService                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │              Ray Cluster                          │  │
│  │                                                   │  │
│  │  ┌──────────────┐        ┌──────────────────┐   │  │
│  │  │  Head Node   │        │   GPU Worker     │   │  │
│  │  │              │        │                  │   │  │
│  │  │  - Dashboard │        │  - vLLM Engine   │   │  │
│  │  │  - Serve API │◄──────►│  - Model Loading │   │  │
│  │  │  - Scheduler │        │  - Inference     │   │  │
│  │  └──────────────┘        └──────────────────┘   │  │
│  │                                                   │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Resource Requirements

**Head Node:**
- CPU: 1 core (500m request)
- Memory: 4Gi (2Gi request)
- No GPU required

**GPU Worker Node:**
- CPU: 2 cores (1 core request)
- Memory: 8Gi (4Gi request)
- GPU: 1x NVIDIA Tesla T4 (or compatible)

## Deployment Steps

### 1. Prepare Application Code

Create a vLLM deployment file (`vllm_app.py`):

```python
from ray import serve
from vllm import LLM, SamplingParams

@serve.deployment(
    ray_actor_options={"num_gpus": 1},
    autoscaling_config={
        "min_replicas": 1,
        "max_replicas": 1,
    }
)
class VLLMDeployment:
    def __init__(self):
        self.llm = LLM(
            model="TinyLlama/TinyLlama-1.1B-Chat-v1.0",
            max_model_len=2048,
            gpu_memory_utilization=0.85,
            tensor_parallel_size=1,
            dtype="float16"
        )
    
    async def __call__(self, request):
        data = await request.json()
        messages = data.get("messages", [])
        
        # Format prompt for TinyLlama chat format
        prompt = ""
        for msg in messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            if role == "system":
                prompt += f"<|system|>\n{content}\n"
            elif role == "user":
                prompt += f"<|user|>\n{content}\n"
            elif role == "assistant":
                prompt += f"<|assistant|>\n{content}\n"
        prompt += "<|assistant|>\n"
        
        # Generate response
        sampling_params = SamplingParams(
            temperature=data.get("temperature", 0.7),
            top_p=data.get("top_p", 0.9),
            max_tokens=data.get("max_tokens", 512)
        )
        
        outputs = self.llm.generate([prompt], sampling_params)
        generated_text = outputs[0].outputs[0].text
        
        # Return OpenAI-compatible format
        return {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": generated_text
                },
                "finish_reason": "stop"
            }]
        }

deployment = VLLMDeployment.bind()
```

### 2. Create ConfigMap for Application Code

```bash
kubectl create configmap -n ai vllm-app-code \
  --from-file=vllm_app.py=./vllm_app.py
```

### 3. Deploy RayService

Create `rayservice.yaml`:

```yaml
apiVersion: ray.io/v1
kind: RayService
metadata:
  name: tinyllama-service
  namespace: ai
spec:
  serviceUnhealthySecondThreshold: 900
  deploymentUnhealthySecondThreshold: 300
  serveConfigV2: |
    proxy_location: EveryNode
    
    applications:
    - name: tinyllama-app
      import_path: vllm_app:deployment
      runtime_env:
        env_vars:
          VLLM_WORKER_MULTIPROC_METHOD: "spawn"
    
  rayClusterConfig:
    rayVersion: '2.49.1'
    enableInTreeAutoscaling: false
    headGroupSpec:
      serviceType: ClusterIP
      rayStartParams:
        dashboard-host: '0.0.0.0'
        dashboard-port: '8265'
        num-gpus: '0'
      template:
        spec:
          containers:
          - name: ray-head
            image: rayproject/ray-llm:2.49.1-py311-cu128
            resources:
              limits:
                cpu: 1
                memory: 4Gi
              requests:
                cpu: 500m
                memory: 2Gi
            ports:
            - containerPort: 6379
              name: gcs-server
            - containerPort: 8265
              name: dashboard
            - containerPort: 10001
              name: client
            - containerPort: 8000
              name: serve
            volumeMounts:
            - mountPath: /home/ray/vllm_app.py
              name: vllm-code
              subPath: vllm_app.py
          volumes:
          - name: vllm-code
            configMap:
              name: vllm-app-code
    
    workerGroupSpecs:
    - replicas: 1
      minReplicas: 1
      maxReplicas: 1
      groupName: gpu-worker-group
      rayStartParams:
        num-gpus: '1'
      template:
        spec:
          containers:
          - name: ray-worker
            image: rayproject/ray-llm:2.49.1-py311-cu128
            lifecycle:
              preStop:
                exec:
                  command: ["/bin/sh", "-c", "ray stop"]
            readinessProbe:
              exec:
                command:
                - bash
                - -c
                - wget --tries 1 -T 2 -q -O- http://localhost:52365/api/local_raylet_healthz | grep success
              initialDelaySeconds: 10
              periodSeconds: 5
              timeoutSeconds: 2
              successThreshold: 1
              failureThreshold: 1
            resources:
              limits:
                cpu: 2
                memory: 8Gi
                nvidia.com/gpu: 1
              requests:
                cpu: 1
                memory: 4Gi
                nvidia.com/gpu: 1
            env:
            - name: CUDA_VISIBLE_DEVICES
              value: "0"
            - name: PYTHONPATH
              value: "/home/ray:$PYTHONPATH"
            volumeMounts:
            - mountPath: /home/ray/vllm_app.py
              name: vllm-code
              subPath: vllm_app.py
          volumes:
          - name: vllm-code
            configMap:
              name: vllm-app-code
          tolerations:
          - key: nvidia.com/gpu
            operator: Exists
            effect: NoSchedule
          - key: nvidia.com/gpu-type
            operator: Equal
            value: nvidia-tesla-t4
            effect: NoSchedule
```

Deploy the RayService:

```bash
kubectl apply -f rayservice.yaml
```

### 4. Monitor Deployment

Check pod status:
```bash
kubectl get pods -n ai
```

Expected output:
```
NAME                                                    READY   STATUS    RESTARTS   AGE
tinyllama-service-xxxxx-gpu-worker-group-worker-xxxxx   1/1     Running   0          2m
tinyllama-service-xxxxx-head-xxxxx                      1/1     Running   0          2m
```

Check RayService status:
```bash
kubectl get rayservice -n ai
```

Check deployment details:
```bash
kubectl exec -n ai <head-pod-name> -c ray-head -- python -c "
import ray
from ray import serve
ray.init()
print(serve.status())
"
```

Expected status: `ApplicationStatus.RUNNING` with `DeploymentStatus.HEALTHY`

## Testing

### Test the Model Endpoint

From inside the cluster:
```bash
kubectl exec -n ai <head-pod-name> -c ray-head -- python -c "
import requests
import json

response = requests.post(
    'http://localhost:8000',
    json={
        'messages': [
            {'role': 'user', 'content': 'Hello! How are you?'}
        ],
        'max_tokens': 100,
        'temperature': 0.7
    }
)

print('Status:', response.status_code)
print('Response:', json.dumps(response.json(), indent=2))
"
```

### Expose Service (Optional)

Create a Service to expose the Ray Serve endpoint:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tinyllama-serve
  namespace: ai
spec:
  type: LoadBalancer
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
    name: serve
  selector:
    ray.io/node-type: head
```

## Troubleshooting

### Common Issues

#### 1. Worker Pod Not Ready

**Symptom**: Worker pod shows `0/1 Ready` for extended period

**Cause**: Readiness probe checking for Serve endpoint (port 8000) which only exists on head nodes

**Solution**: Worker readiness probe should only check raylet health:
```yaml
readinessProbe:
  exec:
    command:
    - bash
    - -c
    - wget --tries 1 -T 2 -q -O- http://localhost:52365/api/local_raylet_healthz | grep success
```

#### 2. Placement Group Scheduling Issues

**Symptom**: Deployment stuck with message "Resources required for each replica: [{"CPU": 2.0, "GPU": 1.0}, {"GPU": 1.0}], total resources available: {}"

**Cause**: Using `ray.serve.llm:build_openai_app` creates placement groups requiring 2 GPU bundles

**Solution**: Use custom vLLM deployment instead of `build_openai_app`

#### 3. Runtime Environment Errors

**Symptom**: "Expected URI but received path /home/ray/vllm_code"

**Cause**: RayService `working_dir` in `runtime_env` only accepts remote URIs (S3, HTTP), not local paths

**Solution**: 
- Mount code via ConfigMap
- Remove `working_dir` from `runtime_env`
- Use `PYTHONPATH` environment variable

#### 4. No GPU Available in Ray

**Symptom**: Ray reports 0 GPUs available even though GPU is allocated to pod

**Cause**: Worker pod not Ready due to failed readiness probe

**Solution**: Fix readiness probe (see issue #1)

### Debugging Commands

Check GPU availability:
```bash
kubectl exec -n ai <worker-pod-name> -c ray-worker -- nvidia-smi
```

Check Ray cluster resources:
```bash
kubectl exec -n ai <head-pod-name> -c ray-head -- ray status
```

Check serve deployment logs:
```bash
kubectl logs -n ai <worker-pod-name> -c ray-worker --tail=100
```

View RayService events:
```bash
kubectl describe rayservice -n ai tinyllama-service
```

Check KubeRay operator logs:
```bash
kubectl logs -n default deployment/kuberay-operator --tail=100
```

## Best Practices

### 1. Resource Allocation

- Always request slightly less CPU than the limit to avoid throttling
- Set `gpu_memory_utilization` to 0.85 (85%) to leave room for CUDA operations
- Use `enforce_eager=false` for better performance with CUDA graphs

### 2. Model Configuration

- Use `tensor_parallel_size=1` for single GPU deployments
- Set appropriate `max_model_len` based on your use case
- Use `dtype="float16"` for faster inference on T4 GPUs

### 3. Deployment Configuration

- Set `min_replicas` and `max_replicas` to 1 for single GPU nodes
- Use `proxy_location: EveryNode` to distribute load
- Configure appropriate health check thresholds

### 4. Monitoring

- Monitor GPU utilization using `nvidia-smi`
- Check Ray dashboard at `http://<head-service>:8265`
- Monitor request latency and throughput
- Set up alerts for deployment health status

## Scaling

### Horizontal Scaling (Multiple GPUs)

To scale to multiple GPUs, increase worker replicas:

```yaml
workerGroupSpecs:
- replicas: 3  # 3 GPU workers
  minReplicas: 1
  maxReplicas: 3
```

Update deployment autoscaling:
```python
autoscaling_config={
    "min_replicas": 1,
    "max_replicas": 3,  # Match number of workers
}
```

### Vertical Scaling (Larger Models)

For larger models requiring multiple GPUs:

```python
self.llm = LLM(
    model="meta-llama/Llama-2-7b-chat-hf",
    tensor_parallel_size=2,  # Use 2 GPUs per replica
    ...
)
```

Update resource requirements:
```yaml
resources:
  limits:
    nvidia.com/gpu: 2  # Request 2 GPUs
```

## Cleanup

Delete the deployment:
```bash
kubectl delete rayservice -n ai tinyllama-service
kubectl delete configmap -n ai vllm-app-code
```

## References

- [Ray Serve Documentation](https://docs.ray.io/en/latest/serve/)
- [KubeRay Documentation](https://docs.ray.io/en/latest/cluster/kubernetes/)
- [vLLM Documentation](https://docs.vllm.ai/)
- [Ray Dashboard](https://docs.ray.io/en/latest/ray-observability/getting-started.html)
