#!/bin/bash
# Quick setup script for build-push.sh

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env file..."
    cat > .env << 'EOF'
# Google Cloud Configuration
GCP_PROJECT_ID=your-project-id
GCP_REGION=us-central1

# Artifact Registry Configuration
AR_REPOSITORY=open-webui

# Docker Image Configuration
IMAGE_TAG=latest
EOF
    echo "✓ Created .env file"
    echo "⚠ Please edit .env and set your GCP_PROJECT_ID"
    echo ""
    echo "Then run:"
    echo "  source .env"
    echo "  ./build-push.sh all"
else
    echo "✓ .env file already exists"
    echo ""
    echo "To use it, run:"
    echo "  source .env"
    echo "  ./build-push.sh all"
fi
