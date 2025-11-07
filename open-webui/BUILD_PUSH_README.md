# Build and Push Script for Open WebUI

This script automates building and pushing Docker images for Open WebUI frontend and backend to Google Artifact Registry.

## Prerequisites

1. **Google Cloud SDK installed and configured**
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Docker installed and running**

## Configuration

Set environment variables before running:

```bash
export GCP_PROJECT_ID=your-project-id
export GCP_REGION=us-central1
export AR_REPOSITORY=open-webui
export IMAGE_TAG=latest
```

Or create a `.env` file and source it:

```bash
# .env
GCP_PROJECT_ID=my-gcp-project
GCP_REGION=us-central1
AR_REPOSITORY=open-webui
IMAGE_TAG=v1.0.0
```

```bash
source .env
```

## Usage

### Show help
```bash
./build-push.sh help
```

### Build only (no push)
```bash
# Build frontend only
./build-push.sh build-fe

# Build backend only
./build-push.sh build-be

# Build both
./build-push.sh build-all
```

### Push only (requires images to be built)
```bash
# Push frontend only
./build-push.sh push-fe

# Push backend only
./build-push.sh push-be

# Push both
./build-push.sh push-all
```

### Build and Push (recommended)
```bash
# Frontend only
./build-push.sh fe

# Backend only
./build-push.sh be

# Both frontend and backend
./build-push.sh all
```

### Clean up local images
```bash
./build-push.sh clean
```

## Examples

### Example 1: Build and push everything
```bash
export GCP_PROJECT_ID=my-project
export IMAGE_TAG=v1.0.0
./build-push.sh all
```

### Example 2: Build and push only frontend with custom tag
```bash
export GCP_PROJECT_ID=my-project
export IMAGE_TAG=dev-20251106
./build-push.sh fe
```

### Example 3: Build locally, test, then push
```bash
# Build images locally
./build-push.sh build-all

# Test images with docker-compose
docker-compose up

# If tests pass, push to registry
export GCP_PROJECT_ID=my-project
./build-push.sh push-all
```

## What the script does

1. **Checks authentication**: Verifies you're logged in to gcloud
2. **Configures Docker**: Sets up Docker to authenticate with Artifact Registry
3. **Creates repository**: Creates the Artifact Registry repository if it doesn't exist
4. **Builds images**: Builds Docker images using Dockerfile.fe and Dockerfile.be
5. **Tags images**: Tags images with the registry path
6. **Pushes images**: Pushes images to Artifact Registry

## Image naming

Images will be pushed to:
```
{REGION}-docker.pkg.dev/{PROJECT_ID}/{REPOSITORY}/open-webui-fe:{TAG}
{REGION}-docker.pkg.dev/{PROJECT_ID}/{REPOSITORY}/open-webui-be:{TAG}
```

Example:
```
us-central1-docker.pkg.dev/my-project/open-webui/open-webui-fe:latest
us-central1-docker.pkg.dev/my-project/open-webui/open-webui-be:latest
```

## Troubleshooting

### Authentication errors
```bash
gcloud auth login
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### Permission errors
Ensure you have the following IAM roles:
- `roles/artifactregistry.writer`
- `roles/storage.admin`

### Repository not found
The script automatically creates the repository, but if it fails:
```bash
gcloud artifacts repositories create open-webui \
    --repository-format=docker \
    --location=us-central1 \
    --description="Open WebUI Docker images"
```

### Build errors
Check:
- You're in the correct directory (`open-webui/`)
- Dockerfile.fe and Dockerfile.be exist
- All required files (CHANGELOG.md, package.json, etc.) exist

## Integration with Helm

After pushing images, update your `helm/open-webui/values.yaml`:

```yaml
frontend:
  image:
    repository: us-central1-docker.pkg.dev/my-project/open-webui/open-webui-fe
    tag: "v1.0.0"

backend:
  image:
    repository: us-central1-docker.pkg.dev/my-project/open-webui/open-webui-be
    tag: "v1.0.0"
```

Then deploy:
```bash
helm upgrade --install open-webui ./helm/open-webui -n open-webui --create-namespace
```
