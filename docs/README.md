# AI Infrastructure - Terraform Configuration

This repository contains Terraform infrastructure as code for deploying an AI infrastructure on Google Cloud Platform (GCP).

## Architecture Overview

The infrastructure includes:
- **VPC Network** with secondary IP ranges for GKE
- **GKE Cluster** with multiple node pools (system, application, and optional GPU)
- **Cloud SQL** PostgreSQL database with enhanced security
- **Artifact Registry** for Docker images
- **Service Accounts** with workload identity

## Prerequisites

- Terraform >= 1.0
- GCP Project with billing enabled
- `gcloud` CLI configured
- Required GCP APIs enabled (see below)

## Required GCP APIs

The following APIs must be enabled in your GCP project:
- Compute Engine API (`compute.googleapis.com`)
- Kubernetes Engine API (`container.googleapis.com`)
- Cloud SQL Admin API (`sqladmin.googleapis.com`)
- Artifact Registry API (`artifactregistry.googleapis.com`)
- IAM Service Account Credentials API (`iamcredentials.googleapis.com`)
- Security Token Service API (`sts.googleapis.com`)

## Quick Start

1. **Clone the repository**
   ```bash
   cd src/terraform/envs/dev
   ```

2. **Copy and configure variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit `terraform.tfvars`** with your values:
   - Set `project_id` to your GCP project ID
   - Set `db_root_password` (required, no default for security)
   - Adjust other variables as needed

4. **Initialize Terraform**
   ```bash
   terraform init
   ```

5. **Review the plan**
   ```bash
   terraform plan
   ```

6. **Apply the configuration**
   ```bash
   terraform apply
   ```

## Module Structure

```
src/terraform/
├── envs/
│   └── dev/                    # Development environment
│       ├── main.tf            # Main configuration
│       ├── variables.tf       # Input variables
│       └── terraform.tfvars   # Variable values (not in git)
└── modules/
    ├── network/               # VPC and subnet configuration
    ├── gke/                   # GKE cluster and node pools
    ├── database/              # Cloud SQL instance
    ├── artifact-registry/     # Artifact Registry repositories
    ├── service-account/       # Service accounts and IAM
    └── workload-identity/     # GCP API enablement
```

## API Management

The `workload-identity` module manages GCP API enablement:
- **Configurable APIs**: Pass a list of APIs to enable via `enable_apis` variable
- **Default APIs**: Artifact Registry, IAM Credentials, STS, Cloud SQL, GKE, Compute Engine
- **Timeouts**: Configured with 30m create and 40m update timeouts
- **Flexible**: Add or remove APIs as needed without modifying the module

## Network Configuration

The network module creates:
- VPC network with custom subnets
- Secondary IP ranges for GKE pods (`10.4.0.0/14`)
- Secondary IP ranges for GKE services (`10.8.0.0/20`)

## GKE Configuration

The GKE module provisions:

### System Node Pool
- **Purpose**: Kubernetes system components
- **Default**: `e2-standard-2` machines
- **Auto-scaling**: 1-3 nodes
- **Taint**: `node-type=system:NoSchedule`

### Application Node Pool
- **Purpose**: Application workloads
- **Default**: `e2-standard-4` machines
- **Auto-scaling**: 1-5 nodes

### GPU Node Pool (Optional)
- **Enabled by**: Set `gke_enable_gpu_pool = true`
- **Default**: `n1-standard-8` with 1x `nvidia-tesla-t4`
- **Supports**: Spot instances for cost savings

## Database Security

Cloud SQL is configured with:
- ✅ Encrypted connections required
- ✅ Point-in-time recovery enabled
- ✅ Automated backups (7-day retention)
- ✅ Transaction log retention
- ✅ Connection and query logging enabled
- ✅ No default password (must be provided)
- ✅ Public IP disabled by default

## Security Best Practices

1. **Database Password**: Store in a secure secret manager, never commit to git
2. **Service Accounts**: Use workload identity for pod authentication
3. **Network**: Use private GKE cluster for production
4. **Backups**: Configured with 7-day retention
5. **Monitoring**: Database flags enable comprehensive logging

## Variable Validation

The configuration includes validation for:
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
