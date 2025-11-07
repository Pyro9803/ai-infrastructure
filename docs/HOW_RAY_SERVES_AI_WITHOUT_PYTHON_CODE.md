# How Ray Serves AI Models Without Custom Python Code

## Overview

The `src/ray-example` directory demonstrates a **configuration-driven approach** to deploying AI models using Ray Serve, where **no custom Python code is required**. Instead, it leverages:

1. **Built-in Ray Serve LLM functions** (`ray.serve.llm:build_openai_app`)
2. **YAML configuration files** (stored in Kubernetes ConfigMaps)
3. **Pre-built Docker images** (`rayproject/ray-llm:2.49.1-py311-cu128`)

This approach is different from the custom vLLM deployment we created in `src/ray/ollama`, where we wrote our own Python deployment class.

---

## Architecture Breakdown

### 1. The Magic: `ray.serve.llm:build_openai_app`

This is a **pre-built function** that ships with the `rayproject/ray-llm` Docker image. It's part of Ray's LLM serving library.

**What it does:**
- Reads YAML configuration files that describe the model
- Automatically creates Ray Serve deployments
- Handles model loading with vLLM
- Exposes an OpenAI-compatible API endpoint
- Manages autoscaling, resource allocation, and GPU scheduling

**Where the code lives:**
- Inside the `rayproject/ray-llm:2.49.1-py311-cu128` Docker image
- Part of the Ray Serve LLM library
- Source: https://github.com/ray-project/ray-llm

### 2. Configuration Files (YAML)

Instead of writing Python code, you define **everything in YAML**:

```yaml
# Example from falcon3-1b-instruct.yaml
model_loading_config:
  model_id: "falcon3-1b-instruct"
  model_source: "tiiuae/Falcon3-1B-Instruct"  # HuggingFace model ID

deployment_config:
  name: "tiiuae/Falcon3-1B-Instruct"
  ray_actor_options:
    num_cpus: 6
    resources:
      small-model-workers: 1  # Custom resource label
  autoscaling_config:
    min_replicas: 1
    max_replicas: 5
    target_ongoing_requests: 85
  max_ongoing_requests: 100

engine_kwargs:
  tensor_parallel_size: 1
  dtype: "float16"
  gpu_memory_utilization: 0.9
  max_model_len: 8192
  enforce_eager: true
  max_num_seqs: 64
  max_num_batched_tokens: 8192
  trust_remote_code: true
```

**This YAML tells Ray Serve:**
- Where to download the model from (HuggingFace)
- How many CPUs/GPUs to use
- How to configure vLLM engine
- When to scale up/down
- What resources are needed

### 3. The RayService Manifest

The RayService YAML ties everything together:

```yaml
serveConfigV2: |
  applications:
  - name: "falcon-h1-3b-instruct-app"
    import_path: "ray.serve.llm:build_openai_app"  # ← Pre-built function
    route_prefix: "/inference/falcon-h1-3b-instruct"
    args:
      llm_configs:
        - models/h1/falcon-h1-3b-instruct.yaml  # ← Path to config
```

**What happens:**
1. Ray Serve reads this configuration
2. Calls `ray.serve.llm:build_openai_app` function
3. Passes the YAML config file path as an argument
4. The function reads the YAML, downloads the model, and creates the deployment

---

## How It Works Step-by-Step

### Step 1: ConfigMaps Store Model Configs

```yaml
# falcon3-family-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: falcon3-family-config
  namespace: ai
data:
  falcon3-1b-instruct.yaml: |
    model_loading_config:
      model_id: "falcon3-1b-instruct"
      model_source: "tiiuae/Falcon3-1B-Instruct"
    # ... rest of config
```

These ConfigMaps are mounted into the Ray pods as files.

### Step 2: RayService Mounts ConfigMaps

```yaml
volumeMounts:
- mountPath: /home/ray/models/falcon3
  name: falcon3-model-config
volumes:
- name: falcon3-model-config
  configMap:
    name: falcon3-family-config
```

Now the YAML files are accessible at `/home/ray/models/falcon3/falcon3-1b-instruct.yaml` inside the container.

### Step 3: Ray Serve Deploys the Application

```yaml
applications:
- name: "falcon3-1b-instruct-app"
  import_path: "ray.serve.llm:build_openai_app"
  args:
    llm_configs:
      - models/falcon3/falcon3-1b-instruct.yaml
```

Ray Serve:
1. Imports `build_openai_app` from `ray.serve.llm` module
2. Calls it with the config file path
3. The function reads the YAML
4. Creates a vLLM deployment
5. Exposes an OpenAI-compatible API

### Step 4: Model Serves Requests

The deployment:
- Downloads the model from HuggingFace
- Loads it into GPU memory with vLLM
- Starts serving on the route prefix `/inference/falcon-h1-3b-instruct`
- Handles requests using OpenAI API format

---

## Comparison: Configuration-Driven vs Custom Code

### Configuration-Driven Approach (src/ray-example)

**Pros:**
- ✅ No Python code needed
- ✅ Uses battle-tested Ray LLM library
- ✅ Declarative - easy to read and modify
- ✅ Supports multiple models easily
- ✅ Built-in OpenAI API compatibility
- ✅ Advanced features (autoscaling, placement groups) work out of the box

**Cons:**
- ❌ Less flexible - limited to what `build_openai_app` supports
- ❌ Harder to customize response format
- ❌ Placement group issues with certain configurations (as we saw)
- ❌ Must follow Ray LLM's YAML schema

**Example:**
```yaml
applications:
- name: "my-model-app"
  import_path: "ray.serve.llm:build_openai_app"
  args:
    llm_configs:
      - /path/to/config.yaml
```

### Custom Code Approach (src/ray/ollama)

**Pros:**
- ✅ Full control over deployment logic
- ✅ Can customize request/response format
- ✅ Easier to debug and understand
- ✅ No placement group complications
- ✅ Can integrate custom business logic

**Cons:**
- ❌ Need to write and maintain Python code
- ❌ Must handle vLLM integration manually
- ❌ More code to test and debug

**Example:**
```python
@serve.deployment(ray_actor_options={"num_gpus": 1})
class VLLMDeployment:
    def __init__(self):
        self.llm = LLM(model="TinyLlama/TinyLlama-1.1B-Chat-v1.0")
    
    async def __call__(self, request):
        # Custom logic here
        pass
```

---

## Why `src/ray-example` Has No Python Files

### The Answer: Everything is Pre-Built

1. **The Docker Image** (`rayproject/ray-llm:2.49.1-py311-cu128`) contains:
   - Ray Serve framework
   - vLLM library
   - `ray.serve.llm` module with `build_openai_app` function
   - All necessary dependencies

2. **The YAML Configs** provide:
   - Model specifications
   - Resource requirements
   - vLLM engine parameters
   - Scaling rules

3. **Kubernetes ConfigMaps** deliver:
   - YAML files to the containers
   - Environment variables
   - Configuration data

### The Flow

```
ConfigMap (YAML) → Mounted to Pod → Ray Serve reads YAML → 
Calls build_openai_app() → vLLM loads model → API ready
```

**No custom Python code needed** because `build_openai_app()` does everything:
- Parses the YAML
- Creates the deployment
- Initializes vLLM
- Handles requests
- Manages scaling

---

## Key Differences from Our Custom Deployment

| Aspect | ray-example (Config-Driven) | ray/ollama (Custom Code) |
|--------|---------------------------|-------------------------|
| **Python Code** | None - uses `ray.serve.llm:build_openai_app` | Custom `VLLMDeployment` class |
| **Configuration** | YAML files in ConfigMaps | Inline in Python + YAML |
| **Complexity** | Lower - declarative | Higher - imperative |
| **Flexibility** | Limited to Ray LLM features | Full control |
| **Deployment Method** | Built-in function | Custom deployment |
| **API Format** | OpenAI-compatible (automatic) | Custom (we implement it) |
| **Placement Groups** | Automatic (can cause issues) | We control it |
| **Maintenance** | Update YAML only | Update Python code |

---

## When to Use Each Approach

### Use Configuration-Driven (like ray-example) when:

- ✅ You need to deploy standard HuggingFace models
- ✅ OpenAI API format is sufficient
- ✅ You want declarative, easy-to-maintain configs
- ✅ You trust Ray's built-in LLM serving
- ✅ You need quick deployment without coding

### Use Custom Code (like ray/ollama) when:

- ✅ You need custom request/response formats
- ✅ You want to integrate business logic
- ✅ You need fine-grained control over vLLM
- ✅ You're having placement group issues
- ✅ You want simpler resource requirements
- ✅ You need to debug deployment behavior

---

## Example: How a Request is Served

### Configuration-Driven Approach

1. **Request arrives:** 
   ```bash
   POST /inference/falcon-h1-3b-instruct/v1/completions
   ```

2. **Ray Serve routes** to the `falcon-h1-3b-instruct-app`

3. **`build_openai_app` function** (pre-built in image):
   - Validates request against OpenAI schema
   - Forwards to vLLM engine
   - Formats response as OpenAI completion

4. **vLLM generates** text using the loaded model

5. **Response returned** in OpenAI format

**You never wrote code for steps 3-5 - it's all in `build_openai_app`!**

### Custom Code Approach

1. **Request arrives:**
   ```bash
   POST /v1/chat/completions
   ```

2. **Ray Serve routes** to `VLLMDeployment.__call__`

3. **Your custom code** runs:
   ```python
   async def __call__(self, request):
       data = await request.json()
       messages = data.get("messages", [])
       # Your custom prompt formatting
       prompt = format_messages(messages)
       # Call vLLM
       outputs = self.llm.generate([prompt], sampling_params)
       # Your custom response format
       return custom_format(outputs)
   ```

4. **You control everything** - formatting, logic, errors

---

## Summary

**The `src/ray-example` directory serves AI models without Python code because:**

1. It uses Ray's **pre-built LLM serving function** (`build_openai_app`)
2. All configuration is in **YAML files** (stored as ConfigMaps)
3. The **Docker image** contains all the necessary code
4. It's a **declarative, configuration-driven approach**

**This is different from our custom approach where:**
- We write Python deployment classes
- We have full control over logic
- We avoid complexity like placement groups
- We define behavior imperatively in code

Both approaches are valid - choose based on your needs:
- **Simple, standard models?** → Use configuration-driven
- **Custom logic, complex requirements?** → Write custom code

---

## Further Reading

- [Ray Serve LLM Documentation](https://docs.ray.io/en/latest/serve/tutorials/vllm-example.html)
- [vLLM Configuration Reference](https://docs.vllm.ai/en/latest/models/engine_args.html)
- [Ray Serve Deployment Guide](https://docs.ray.io/en/latest/serve/index.html)
- Our custom deployment: `src/ray/ollama/vllm_app.py`
- Configuration example: `src/ray-example/models/falcon3-family-configmap.yaml`
