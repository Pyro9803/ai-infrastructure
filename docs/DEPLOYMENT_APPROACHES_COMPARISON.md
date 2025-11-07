# AI Model Deployment Approaches Comparison

This document provides a side-by-side comparison of the two AI model deployment approaches used in this repository.

---

## Quick Comparison Table

| Feature | Configuration-Driven<br>(`src/ray-example`) | Custom Code<br>(`src/ray/ollama`) |
|---------|-------------------------------------------|----------------------------------|
| **Python Code Required** | ❌ No | ✅ Yes (`vllm_app.py`) |
| **Deployment Method** | `ray.serve.llm:build_openai_app` | Custom `@serve.deployment` class |
| **Configuration** | YAML ConfigMaps only | YAML + Python code |
| **Learning Curve** | Lower (declarative) | Medium (need Python/Ray knowledge) |
| **Flexibility** | Limited to Ray LLM features | Full control over logic |
| **Custom Logic** | ❌ Not supported | ✅ Fully customizable |
| **API Format** | OpenAI-compatible (fixed) | Custom (you define it) |
| **Placement Groups** | Auto-created (can cause issues) | Manual control |
| **Debugging** | Harder (code is in image) | Easier (your code is visible) |
| **Multi-Model Support** | ✅ Excellent (just add YAML) | ⚠️ Need code per model type |
| **Production Ready** | ✅ Ray's battle-tested code | ⚠️ Depends on your code quality |
| **Best For** | Standard models, quick deployment | Custom logic, specific requirements |

---

## Approach 1: Configuration-Driven (`src/ray-example`)

### How It Works

```yaml
# In RayService manifest
serveConfigV2: |
  applications:
  - name: "falcon3-1b-instruct-app"
    import_path: "ray.serve.llm:build_openai_app"  # Pre-built function
    args:
      llm_configs:
        - models/falcon3/falcon3-1b-instruct.yaml  # Config file path
```

```yaml
# In ConfigMap (falcon3-1b-instruct.yaml)
model_loading_config:
  model_id: "falcon3-1b-instruct"
  model_source: "tiiuae/Falcon3-1B-Instruct"

deployment_config:
  ray_actor_options:
    num_cpus: 6
    num_gpus: 1
  autoscaling_config:
    min_replicas: 1
    max_replicas: 5

engine_kwargs:
  dtype: "float16"
  gpu_memory_utilization: 0.9
  max_model_len: 8192
```

### What You Get

- ✅ **Zero Python code** - everything in YAML
- ✅ **OpenAI-compatible API** - works with OpenAI SDKs
- ✅ **Built-in features** - autoscaling, placement groups, health checks
- ✅ **Quick deployment** - just create ConfigMaps and apply
- ✅ **Multi-model support** - add more models by adding YAML files

### Limitations

- ❌ **Fixed API format** - must use OpenAI schema
- ❌ **No custom logic** - can't add authentication, logging, etc.
- ❌ **Placement group issues** - automatic placement groups can fail with resource constraints
- ❌ **Limited debugging** - code is inside Docker image
- ❌ **Schema constraints** - must follow Ray LLM YAML schema exactly

### When to Use

✅ **Use configuration-driven when you:**
- Need standard HuggingFace model deployment
- Want OpenAI-compatible API
- Prefer declarative configuration
- Need to deploy multiple similar models quickly
- Don't need custom request/response handling
- Trust Ray's built-in implementation

**Example use cases:**
- Internal API gateway for multiple LLMs
- Quick proof-of-concept deployments
- Standard model serving with minimal customization
- Teams without Python expertise

---

## Approach 2: Custom Code (`src/ray/ollama`)

### How It Works

```python
# vllm_app.py
from ray import serve
from vllm import LLM, SamplingParams

@serve.deployment(
    ray_actor_options={"num_gpus": 1},
    autoscaling_config={"min_replicas": 1, "max_replicas": 1}
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
        # Custom logic here
        messages = data.get("messages", [])
        prompt = self.format_prompt(messages)  # Your formatting
        
        sampling_params = SamplingParams(
            temperature=data.get("temperature", 0.7),
            max_tokens=data.get("max_tokens", 512)
        )
        
        outputs = self.llm.generate([prompt], sampling_params)
        
        # Return custom format
        return {
            "model": "TinyLlama",
            "response": outputs[0].outputs[0].text,
            # Add any custom fields you want
        }

deployment = VLLMDeployment.bind()
```

```yaml
# In RayService
serveConfigV2: |
  applications:
  - name: tinyllama-app
    import_path: vllm_app:deployment  # Your Python file
    runtime_env:
      env_vars:
        VLLM_WORKER_MULTIPROC_METHOD: "spawn"
```

### What You Get

- ✅ **Full control** - customize everything
- ✅ **Custom API format** - define your own request/response
- ✅ **Add business logic** - authentication, rate limiting, logging, etc.
- ✅ **Easier debugging** - your code is visible and editable
- ✅ **Simple resources** - no complex placement groups
- ✅ **Integration flexibility** - call external services, databases, etc.

### Limitations

- ❌ **Need Python knowledge** - must write and maintain code
- ❌ **More code** - more to test and debug
- ❌ **Manual implementation** - need to implement features yourself
- ❌ **Deployment complexity** - need ConfigMap for Python code
- ❌ **Per-model code** - different models may need different classes

### When to Use

✅ **Use custom code when you:**
- Need custom request/response formats
- Want to add authentication or rate limiting
- Need to integrate with other systems
- Have specific business logic requirements
- Want full control over deployment behavior
- Need to debug and troubleshoot easily
- Have Python/Ray development expertise

**Example use cases:**
- Production APIs with custom authentication
- Integration with existing systems
- Custom prompt engineering pipelines
- Multi-step AI workflows
- Special response formatting requirements
- APIs requiring logging/monitoring integration

---

## Side-by-Side Example: Deploying the Same Model

### Configuration-Driven Approach

**Files needed:**
1. ConfigMap with model config
2. RayService YAML

**ConfigMap (`tinyllama-config.yaml`):**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tinyllama-config
data:
  tinyllama.yaml: |
    model_loading_config:
      model_id: "tinyllama"
      model_source: "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
    deployment_config:
      ray_actor_options:
        num_gpus: 1
      autoscaling_config:
        min_replicas: 1
        max_replicas: 1
    engine_kwargs:
      dtype: "float16"
      gpu_memory_utilization: 0.85
      max_model_len: 2048
```

**RayService:**
```yaml
serveConfigV2: |
  applications:
  - name: tinyllama-app
    import_path: "ray.serve.llm:build_openai_app"
    route_prefix: "/v1"
    args:
      llm_configs:
        - /home/ray/models/tinyllama.yaml
```

**Request:**
```bash
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tinyllama",
    "prompt": "Hello, how are you?",
    "max_tokens": 50
  }'
```

### Custom Code Approach

**Files needed:**
1. Python deployment file
2. ConfigMap with Python code
3. RayService YAML

**Python Code (`vllm_app.py`):**
```python
from ray import serve
from vllm import LLM, SamplingParams

@serve.deployment(ray_actor_options={"num_gpus": 1})
class VLLMDeployment:
    def __init__(self):
        self.llm = LLM(
            model="TinyLlama/TinyLlama-1.1B-Chat-v1.0",
            max_model_len=2048,
            gpu_memory_utilization=0.85,
            dtype="float16"
        )
    
    async def __call__(self, request):
        data = await request.json()
        messages = data.get("messages", [])
        
        # Custom prompt formatting
        prompt = ""
        for msg in messages:
            prompt += f"{msg['role']}: {msg['content']}\n"
        
        outputs = self.llm.generate(
            [prompt],
            SamplingParams(
                max_tokens=data.get("max_tokens", 50)
            )
        )
        
        return {
            "response": outputs[0].outputs[0].text,
            "model": "TinyLlama"
        }

deployment = VLLMDeployment.bind()
```

**ConfigMap:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vllm-app-code
data:
  vllm_app.py: |
    # Python code here
```

**RayService:**
```yaml
serveConfigV2: |
  applications:
  - name: tinyllama-app
    import_path: vllm_app:deployment
    route_prefix: "/"
    runtime_env:
      env_vars:
        VLLM_WORKER_MULTIPROC_METHOD: "spawn"
```

**Request:**
```bash
curl -X POST http://localhost:8000/ \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "max_tokens": 50
  }'
```

---

## Decision Flow Chart

```
Do you need custom request/response format?
├─ YES → Use Custom Code Approach
└─ NO
    ↓
    Do you need custom business logic (auth, logging, etc.)?
    ├─ YES → Use Custom Code Approach
    └─ NO
        ↓
        Do you have Python/Ray expertise?
        ├─ NO → Use Configuration-Driven Approach
        └─ YES
            ↓
            Do you need to deploy multiple similar models?
            ├─ YES → Use Configuration-Driven Approach
            └─ NO
                ↓
                Do you prefer declarative config over code?
                ├─ YES → Use Configuration-Driven Approach
                └─ NO → Use Custom Code Approach
```

---

## Hybrid Approach (Advanced)

You can combine both approaches:

```yaml
serveConfigV2: |
  applications:
  # Standard models use configuration-driven
  - name: "falcon3-1b"
    import_path: "ray.serve.llm:build_openai_app"
    args:
      llm_configs:
        - /home/ray/models/falcon3-1b.yaml
  
  # Custom model uses custom code
  - name: "tinyllama-custom"
    import_path: "custom_deployment:app"
    route_prefix: "/custom"
```

**Benefits:**
- Use configuration-driven for standard models
- Use custom code where you need flexibility
- Best of both worlds

---

## Migration Path

### From Configuration-Driven to Custom Code

If you start with configuration and later need customization:

1. **Extract the YAML config** - use it as reference for parameters
2. **Create Python deployment** - implement the same model loading
3. **Add custom logic** - implement your specific requirements
4. **Update RayService** - change `import_path` to your Python file
5. **Test thoroughly** - ensure behavior matches original

### From Custom Code to Configuration-Driven

If you have custom code but want simpler maintenance:

1. **Check compatibility** - ensure your use case fits Ray LLM
2. **Create YAML config** - translate your Python config to YAML
3. **Remove custom logic** - move to middleware if needed
4. **Update RayService** - use `build_openai_app`
5. **Test API compatibility** - may need to update clients

---

## Recommendations

### For Production Systems

**Start with Configuration-Driven if:**
- You're serving standard HuggingFace models
- You want to minimize custom code
- Your team prefers YAML/declarative config
- You need quick time-to-market

**Migrate to Custom Code when:**
- You hit limitations of configuration approach
- You need custom authentication/authorization
- You require specific business logic
- You need tight integration with other systems

### For Development/Testing

**Configuration-Driven is ideal:**
- Fast iteration on model selection
- Testing different models quickly
- Proof-of-concept deployments
- Learning Ray Serve

**Custom Code is better when:**
- You're experimenting with vLLM features
- You need to understand deployment internals
- You're building a library/framework
- You want maximum control for debugging

---

## Real-World Examples

### Example 1: Startup AI API Platform

**Choice:** Configuration-Driven  
**Reason:**
- Need to deploy 10+ different models quickly
- Team has limited Python expertise
- Want standard OpenAI-compatible API
- Focus on model selection, not infrastructure

### Example 2: Enterprise Internal AI Service

**Choice:** Custom Code  
**Reason:**
- Need SSO integration
- Require audit logging
- Custom rate limiting per department
- Integration with existing authentication

### Example 3: Research Lab

**Choice:** Hybrid  
**Reason:**
- Most models use configuration (quick deployment)
- Experimental models use custom code (flexibility)
- Can compare approaches easily

---

## Conclusion

Both approaches are valid and solve different problems:

- **Configuration-Driven (`ray-example`)**: Best for standard deployments, quick iteration, teams without Python expertise
- **Custom Code (`ray/ollama`)**: Best for custom requirements, full control, complex integrations

**Choose based on your specific needs, and remember you can always migrate between approaches as requirements evolve.**

---

## Further Reading

- [Configuration-Driven Deep Dive](./HOW_RAY_SERVES_AI_WITHOUT_PYTHON_CODE.md)
- [Custom Deployment Guide](./MODEL_DEPLOYMENT_GUIDE.md)
- [Ray Serve Documentation](https://docs.ray.io/en/latest/serve/)
- [vLLM Documentation](https://docs.vllm.ai/)
