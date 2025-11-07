# AI Infrastructure Documentation# AI Infrastructure - Terraform Configuration



This directory contains comprehensive documentation for deploying and managing AI infrastructure on Google Cloud Platform with Kubernetes.This repository contains Terraform infrastructure as code for deploying an AI infrastructure on Google Cloud Platform (GCP).



## 📚 Documentation Index## Architecture Overview



### Infrastructure GuidesThe infrastructure includes:

- **VPC Network** with secondary IP ranges for GKE

- **Terraform Infrastructure** (`../src/terraform/`) - Complete guide for provisioning GCP infrastructure- **GKE Cluster** with multiple node pools (system, application, and optional GPU)

  - VPC Network configuration- **Cloud SQL** PostgreSQL database with enhanced security

  - GKE cluster setup with GPU node pools- **Artifact Registry** for Docker images

  - Cloud SQL database- **Service Accounts** with workload identity

  - Artifact Registry

  - Service Accounts and Workload Identity## Prerequisites



### Model Deployment Guides- Terraform >= 1.0

- GCP Project with billing enabled

- **[Model Deployment Guide](MODEL_DEPLOYMENT_GUIDE.md)** ⭐ **RECOMMENDED** - Complete guide for deploying LLM models using Ray Serve- `gcloud` CLI configured

  - Step-by-step deployment instructions- Required GCP APIs enabled (see below)

  - Troubleshooting common issues

  - Best practices and configuration## Required GCP APIs

  - Monitoring and scaling

The following APIs must be enabled in your GCP project:

- **[AI Model Deployment Guide](AI_MODEL_DEPLOYMENT_GUIDE.md)** - Advanced multi-model deployment architecture- Compute Engine API (`compute.googleapis.com`)

  - Multi-tier GPU support (T4, L4, A100)- Kubernetes Engine API (`container.googleapis.com`)

  - Auto-scaling configurations- Cloud SQL Admin API (`sqladmin.googleapis.com`)

  - OpenAI-compatible API endpoints- Artifact Registry API (`artifactregistry.googleapis.com`)

- IAM Service Account Credentials API (`iamcredentials.googleapis.com`)

- **[GPT-OSS Deployment Guide](GPT_OSS_DEPLOYMENT_GUIDE.md)** - Deploying open-source GPT models- Security Token Service API (`sts.googleapis.com`)

  - GPT-J, Falcon, and other OSS models

  - Ray Serve integration patterns## Quick Start



### Quick Start Guides1. **Clone the repository**

   ```bash

- **[Serve AI](serve-ai.md)** - Quick start for serving AI models   cd src/terraform/envs/dev

- **[GPT-OSS Quick Start](gpt-oss.md)** - Fast deployment of GPT models   ```



## 🚀 Quick Start2. **Copy and configure variables**

   ```bash

### For Model Deployment   cp terraform.tfvars.example terraform.tfvars

   ```

If you want to deploy an LLM model quickly:

3. **Edit `terraform.tfvars`** with your values:

1. **Prerequisites**: Kubernetes cluster with GPU nodes   - Set `project_id` to your GCP project ID

2. **Follow**: [Model Deployment Guide](MODEL_DEPLOYMENT_GUIDE.md)   - Set `db_root_password` (required, no default for security)

3. **Example**: TinyLlama deployment in `src/ray/ollama/`   - Adjust other variables as needed



### For Infrastructure Setup4. **Initialize Terraform**

   ```bash

If you need to provision the infrastructure first:   terraform init

   ```

1. **Prerequisites**: GCP project with billing enabled

2. **Follow**: Terraform documentation in `src/terraform/`5. **Review the plan**

3. **Configure**: Set up variables in `src/terraform/envs/dev/terraform.tfvars`   ```bash

   terraform plan

## 📁 Repository Structure   ```



```6. **Apply the configuration**

ai-infrastructure/   ```bash

├── docs/                          # 📚 Documentation   terraform apply

│   ├── README.md                  # This file   ```

│   ├── MODEL_DEPLOYMENT_GUIDE.md  # ⭐ Main deployment guide

│   ├── AI_MODEL_DEPLOYMENT_GUIDE.md## Module Structure

│   └── GPT_OSS_DEPLOYMENT_GUIDE.md

├── src/```

│   ├── ray/                       # Ray Serve deploymentssrc/terraform/

│   │   ├── ollama/               # TinyLlama example├── envs/

│   │   └── gpt-models/           # GPT models│   └── dev/                    # Development environment

│   └── terraform/                # Infrastructure as Code│       ├── main.tf            # Main configuration

│       ├── envs/                 # Environment configurations│       ├── variables.tf       # Input variables

│       └── modules/              # Terraform modules│       └── terraform.tfvars   # Variable values (not in git)

```└── modules/

    ├── network/               # VPC and subnet configuration

## 🎯 Common Tasks    ├── gke/                   # GKE cluster and node pools

    ├── database/              # Cloud SQL instance

### Deploy a New Model    ├── artifact-registry/     # Artifact Registry repositories

    ├── service-account/       # Service accounts and IAM

```bash    └── workload-identity/     # GCP API enablement

# 1. Create application code (see MODEL_DEPLOYMENT_GUIDE.md)```

# 2. Create ConfigMap

kubectl create configmap -n ai model-code --from-file=app.py## API Management



# 3. Deploy RayServiceThe `workload-identity` module manages GCP API enablement:

kubectl apply -f rayservice.yaml- **Configurable APIs**: Pass a list of APIs to enable via `enable_apis` variable

- **Default APIs**: Artifact Registry, IAM Credentials, STS, Cloud SQL, GKE, Compute Engine

# 4. Monitor deployment- **Timeouts**: Configured with 30m create and 40m update timeouts

kubectl get pods -n ai- **Flexible**: Add or remove APIs as needed without modifying the module

kubectl get rayservice -n ai

```## Network Configuration



### Scale Model DeploymentThe network module creates:

- VPC network with custom subnets

```yaml- Secondary IP ranges for GKE pods (`10.4.0.0/14`)

# Edit rayservice.yaml- Secondary IP ranges for GKE services (`10.8.0.0/20`)

workerGroupSpecs:

- replicas: 3  # Increase replicas## GKE Configuration

  autoscaling_config:

    max_replicas: 5  # Set max replicasThe GKE module provisions:

```

### System Node Pool

### View Model Logs- **Purpose**: Kubernetes system components

- **Default**: `e2-standard-2` machines

```bash- **Auto-scaling**: 1-3 nodes

# Get pod name- **Taint**: `node-type=system:NoSchedule`

kubectl get pods -n ai

### Application Node Pool

# View logs- **Purpose**: Application workloads

kubectl logs -n ai <pod-name> -c ray-worker --tail=100- **Default**: `e2-standard-4` machines

```- **Auto-scaling**: 1-5 nodes



## 🛠️ Troubleshooting### GPU Node Pool (Optional)

- **Enabled by**: Set `gke_enable_gpu_pool = true`

### Common Issues- **Default**: `n1-standard-8` with 1x `nvidia-tesla-t4`

- **Supports**: Spot instances for cost savings

1. **Pod not ready** → Check readiness probe configuration

2. **GPU not available** → Verify GPU node pool and tolerations## Database Security

3. **Model loading timeout** → Increase resource limits

4. **API errors** → Check serve deployment statusCloud SQL is configured with:

- ✅ Encrypted connections required

See [Troubleshooting Section](MODEL_DEPLOYMENT_GUIDE.md#troubleshooting) for detailed solutions.- ✅ Point-in-time recovery enabled

- ✅ Automated backups (7-day retention)

## 📖 Additional Resources- ✅ Transaction log retention

- ✅ Connection and query logging enabled

- [Ray Documentation](https://docs.ray.io/)- ✅ No default password (must be provided)

- [Ray Serve](https://docs.ray.io/en/latest/serve/)- ✅ Public IP disabled by default

- [KubeRay](https://docs.ray.io/en/latest/cluster/kubernetes/)

- [vLLM Documentation](https://docs.vllm.ai/)## Security Best Practices

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)

1. **Database Password**: Store in a secure secret manager, never commit to git

## 🤝 Contributing2. **Service Accounts**: Use workload identity for pod authentication

3. **Network**: Use private GKE cluster for production

When adding new documentation:4. **Backups**: Configured with 7-day retention

1. Keep guides focused and practical5. **Monitoring**: Database flags enable comprehensive logging

2. Include working examples

3. Add troubleshooting sections## Variable Validation

4. Update this index

5. Test all commands before committingThe configuration includes validation for:

- Region format (e.g., `asia-southeast1`)
- CIDR blocks (valid IPv4 format)
- Machine types (valid GCP format)
- Disk sizes (10 GB - 65536 GB)
- Repository formats (DOCKER, MAVEN, NPM, etc.)

## Outputs

Each module provides outputs that can be referenced:
- Network: VPC name, subnet details
- GKE: Cluster name, endpoint, CA certificate
- Database: Instance name, connection name, IP addresses
- Service Accounts: Email addresses

## Cost Optimization

- Use spot instances for GPU nodes (`gke_gpu_spot = true`)
- Adjust node pool sizes based on workload
- Use `db-f1-micro` for development (default)
- Enable autoscaling to scale down during low usage

## Troubleshooting

### Common Issues

1. **API not enabled**: Run the workload-identity module first to enable required APIs
2. **Quota exceeded**: Request quota increase in GCP console
3. **Database password**: Ensure `db_root_password` is set in tfvars

## Contributing

When making changes:
1. Run `terraform fmt -recursive` before committing
2. Run `terraform validate` to check syntax
3. Test in a development environment first
4. Update this README if adding new features

## License

[Add your license here]
