# TinyLlama Model Deployment

This directory contains the deployment configuration for TinyLlama 1.1B Chat model using Ray Serve on Kubernetes.

## Files

- `vllm_app.py` - vLLM deployment application code
- `tinyllama-rayservice.yaml` - RayService configuration for deploying the model

## Quick Start

### 1. Create ConfigMap with Application Code

```bash
kubectl create configmap -n ai vllm-app-code \
  --from-file=vllm_app.py=./vllm_app.py
```

### 2. Deploy the Model

```bash
kubectl apply -f tinyllama-rayservice.yaml
```

### 3. Check Deployment Status

```bash
# Check pods
kubectl get pods -n ai

# Check RayService
kubectl get rayservice -n ai

# Check deployment details
kubectl exec -n ai $(kubectl get po -n ai -l ray.io/node-type=head -o name | head -1) \
  -c ray-head -- python -c "import ray; from ray import serve; ray.init(); print(serve.status())"
```

### 4. Test the Model

```bash
kubectl exec -n ai $(kubectl get po -n ai -l ray.io/node-type=head -o name | head -1) \
  -c ray-head -- python -c "
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

## Model Details

- **Model**: TinyLlama/TinyLlama-1.1B-Chat-v1.0
- **Engine**: vLLM 
- **GPU**: 1x NVIDIA Tesla T4 (or compatible)
- **Memory**: 8Gi RAM + 1x GPU (15GB VRAM)
- **Precision**: float16

## Configuration

### Resource Requirements

**Head Node:**
- CPU: 1 core (500m request, 1 limit)
- Memory: 4Gi (2Gi request, 4Gi limit)
- No GPU

**GPU Worker:**
- CPU: 2 cores (1 core request, 2 limit)
- Memory: 8Gi (4Gi request, 8Gi limit)
- GPU: 1x NVIDIA Tesla T4

### Model Parameters

The model is configured with:
- `max_model_len`: 2048 tokens
- `gpu_memory_utilization`: 0.85 (85%)
- `tensor_parallel_size`: 1
- `dtype`: float16

### API Format

The service exposes an OpenAI-compatible chat completion API:

**Endpoint**: `http://localhost:8000` (inside cluster)

**Request Format**:
```json
{
  "messages": [
    {"role": "user", "content": "Your question here"}
  ],
  "max_tokens": 100,
  "temperature": 0.7,
  "top_p": 0.9
}
```

**Response Format**:
```json
{
  "id": "chatcmpl-123",
  "object": "chat.completion",
  "created": 1677652288,
  "model": "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
  "choices": [{
    "index": 0,
    "message": {
      "role": "assistant",
      "content": "Generated response text"
    },
    "finish_reason": "stop"
  }]
}
```

## Cleanup

```bash
# Delete the RayService
kubectl delete rayservice -n ai tinyllama-service

# Delete the ConfigMap
kubectl delete configmap -n ai vllm-app-code
```

## Troubleshooting

See the main [Model Deployment Guide](../../../docs/MODEL_DEPLOYMENT_GUIDE.md) for detailed troubleshooting steps.

### Quick Checks

1. **Check if GPU is available**:
   ```bash
   kubectl exec -n ai <worker-pod> -c ray-worker -- nvidia-smi
   ```

2. **Check Ray cluster resources**:
   ```bash
   kubectl exec -n ai <head-pod> -c ray-head -- ray status
   ```

3. **View deployment logs**:
   ```bash
   kubectl logs -n ai <worker-pod> -c ray-worker --tail=100
   ```

4. **Check RayService events**:
   ```bash
   kubectl describe rayservice -n ai tinyllama-service
   ```
