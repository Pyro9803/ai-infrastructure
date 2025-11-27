#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
# PROJECT_ID="${GCP_PROJECT_ID:-your-project-id}"
# REGION="${GCP_REGION:-us-central1}"
# REPOSITORY="${AR_REPOSITORY:-open-webui}"
# REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}"
# GCP Project Configuration
PROJECT_ID="tutorial-475402"
REGION="asia-southeast1"
REPOSITORY="dev-artifact-repo"
REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}"

FE_IMAGE_NAME="open-webui-fe"
BE_IMAGE_NAME="open-webui-be"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if gcloud is authenticated
check_gcloud_auth() {
    print_info "Checking gcloud authentication..."
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        print_error "Not authenticated with gcloud. Please run: gcloud auth login"
        exit 1
    fi
    print_info "✓ Authenticated with gcloud"
}

# Function to configure docker for artifact registry
configure_docker() {
    print_info "Configuring Docker for Artifact Registry..."
    gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet
    print_info "✓ Docker configured"
}

# Function to create artifact registry repository if not exists
create_repository() {
    print_info "Checking if Artifact Registry repository exists..."
    if ! gcloud artifacts repositories describe ${REPOSITORY} \
        --location=${REGION} \
        --project=${PROJECT_ID} &>/dev/null; then
        
        print_warn "Repository does not exist. Creating..."
        gcloud artifacts repositories create ${REPOSITORY} \
            --repository-format=docker \
            --location=${REGION} \
            --description="Open WebUI Docker images" \
            --project=${PROJECT_ID}
        print_info "✓ Repository created"
    else
        print_info "✓ Repository exists"
    fi
}

# Function to build frontend image
build_fe() {
    print_info "Building frontend image..."
    docker build -f Dockerfile.fe -t ${FE_IMAGE_NAME}:${IMAGE_TAG} .
    print_info "✓ Frontend image built: ${FE_IMAGE_NAME}:${IMAGE_TAG}"
}

# Function to build backend image
build_be() {
    print_info "Building backend image..."
    docker build -f Dockerfile.be -t ${BE_IMAGE_NAME}:${IMAGE_TAG} .
    print_info "✓ Backend image built: ${BE_IMAGE_NAME}:${IMAGE_TAG}"
}

# Function to tag and push frontend image
push_fe() {
    print_info "Tagging and pushing frontend image..."
    
    # Tag for registry
    docker tag ${FE_IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${FE_IMAGE_NAME}:${IMAGE_TAG}
    
    # Push to registry
    docker push ${REGISTRY}/${FE_IMAGE_NAME}:${IMAGE_TAG}
    
    print_info "✓ Frontend image pushed: ${REGISTRY}/${FE_IMAGE_NAME}:${IMAGE_TAG}"
}

# Function to tag and push backend image
push_be() {
    print_info "Tagging and pushing backend image..."
    
    # Tag for registry
    docker tag ${BE_IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${BE_IMAGE_NAME}:${IMAGE_TAG}
    
    # Push to registry
    docker push ${REGISTRY}/${BE_IMAGE_NAME}:${IMAGE_TAG}
    
    print_info "✓ Backend image pushed: ${REGISTRY}/${BE_IMAGE_NAME}:${IMAGE_TAG}"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTION]

Build and push Open WebUI Docker images to Google Artifact Registry

OPTIONS:
    build-fe            Build frontend image only
    build-be            Build backend image only
    build-all           Build both frontend and backend images
    
    push-fe             Push frontend image (must be built first)
    push-be             Push backend image (must be built first)
    push-all            Push both images (must be built first)
    
    all                 Build and push both images
    fe                  Build and push frontend image only
    be                  Build and push backend image only
    
    clean               Remove local images
    
    help                Show this help message

ENVIRONMENT VARIABLES:
    GCP_PROJECT_ID      GCP Project ID (default: your-project-id)
    GCP_REGION          GCP Region (default: us-central1)
    AR_REPOSITORY       Artifact Registry repository name (default: open-webui)
    IMAGE_TAG           Docker image tag (default: latest)

EXAMPLES:
    # Set environment variables
    export GCP_PROJECT_ID=my-project
    export GCP_REGION=us-central1
    export IMAGE_TAG=v1.0.0
    
    # Build and push frontend only
    $0 fe
    
    # Build and push backend only
    $0 be
    
    # Build and push both
    $0 all
    
    # Build only (no push)
    $0 build-all
    
    # Push existing images
    $0 push-all

EOF
}

# Function to clean local images
clean() {
    print_info "Removing local images..."
    docker rmi ${FE_IMAGE_NAME}:${IMAGE_TAG} 2>/dev/null || true
    docker rmi ${BE_IMAGE_NAME}:${IMAGE_TAG} 2>/dev/null || true
    docker rmi ${REGISTRY}/${FE_IMAGE_NAME}:${IMAGE_TAG} 2>/dev/null || true
    docker rmi ${REGISTRY}/${BE_IMAGE_NAME}:${IMAGE_TAG} 2>/dev/null || true
    print_info "✓ Cleanup complete"
}

# Main script logic
main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    case "$1" in
        build-fe)
            build_fe
            ;;
        build-be)
            build_be
            ;;
        build-all)
            build_fe
            build_be
            ;;
        push-fe)
            check_gcloud_auth
            configure_docker
            create_repository
            push_fe
            ;;
        push-be)
            check_gcloud_auth
            configure_docker
            create_repository
            push_be
            ;;
        push-all)
            check_gcloud_auth
            configure_docker
            create_repository
            push_fe
            push_be
            ;;
        fe)
            build_fe
            check_gcloud_auth
            configure_docker
            create_repository
            push_fe
            ;;
        be)
            build_be
            check_gcloud_auth
            configure_docker
            create_repository
            push_be
            ;;
        all)
            build_fe
            build_be
            check_gcloud_auth
            configure_docker
            create_repository
            push_fe
            push_be
            ;;
        clean)
            clean
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac

    print_info "✨ Done!"
}

# Run main function
main "$@"
