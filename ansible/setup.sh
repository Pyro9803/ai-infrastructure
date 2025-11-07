#!/bin/bash
# Setup script for Ansible automation
set -e

echo "=========================================="
echo "Ansible Setup for AI Infrastructure"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Python
echo -e "${YELLOW}[1/5] Checking Python...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Python 3 is installed: $(python3 --version)${NC}"
echo ""

# Check pip
echo -e "${YELLOW}[2/5] Checking pip...${NC}"
if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}Error: pip3 is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ pip3 is installed: $(pip3 --version)${NC}"
echo ""

# Install Ansible
echo -e "${YELLOW}[3/5] Installing Ansible...${NC}"
if ! command -v ansible &> /dev/null; then
    echo "Installing Ansible..."
    pip3 install ansible
else
    echo -e "${GREEN}✓ Ansible is already installed: $(ansible --version | head -1)${NC}"
fi
echo ""

# Install Ansible collections
echo -e "${YELLOW}[4/5] Installing Ansible collections...${NC}"
cd "$(dirname "$0")"
ansible-galaxy collection install -r requirements.yml
echo -e "${GREEN}✓ Ansible collections installed${NC}"
echo ""

# Verify tools
echo -e "${YELLOW}[5/5] Verifying required tools...${NC}"
echo ""

echo -n "kubectl: "
if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}✓ $(kubectl version --client --short 2>&1 | head -1)${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    echo "   Install: https://kubernetes.io/docs/tasks/tools/"
fi

echo -n "gcloud: "
if command -v gcloud &> /dev/null; then
    echo -e "${GREEN}✓ $(gcloud version 2>&1 | head -1)${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    echo "   Install: https://cloud.google.com/sdk/docs/install"
fi

echo -n "terraform: "
if command -v terraform &> /dev/null; then
    echo -e "${GREEN}✓ $(terraform version | head -1)${NC}"
else
    echo -e "${RED}✗ Not found${NC}"
    echo "   Install: https://www.terraform.io/downloads"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Configure GCP authentication:"
echo "   gcloud auth login"
echo "   gcloud auth application-default login"
echo ""
echo "2. Apply Terraform infrastructure:"
echo "   cd ../src/terraform/envs/prod"
echo "   terraform apply"
echo ""
echo "3. Deploy TinyLlama with Ansible:"
echo "   cd ansible"
echo "   ansible-playbook -i inventory/hosts.yml deploy-tinyllama.yml -e env=prod"
echo ""
