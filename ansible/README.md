# Ansible Automation for TinyLlama Deployment

This directory contains Ansible automation following **best practices** with a role-based structure to deploy the TinyLlama model on GKE.

## 📁 Structure (Best Practices)

```
ansible/
├── site.yml                      # Main playbook
├── cleanup.yml                   # Cleanup playbook
├── inventory/                    # Inventory files
│   └── hosts.yml                 
├── group_vars/                   # Group variables
│   ├── all.yml                   
│   ├── dev.yml                   
│   └── prod.yml                  
└── roles/                        # Ansible roles
    └── tinyllama_deploy/         
        ├── tasks/                # Task files (modular)
        ├── handlers/             # Event handlers
        ├── defaults/             # Default variables
        ├── vars/                 # Role variables
        ├── files/                # Static files
        ├── templates/            # Jinja2 templates
        └── meta/                 # Role metadata
```

## 🚀 Quick Start

```bash
# Setup (one-time)
./setup.sh

# Deploy to dev
ansible-playbook site.yml -i inventory -e deploy_environment=dev

# Deploy to prod
ansible-playbook site.yml -i inventory -e deploy_environment=prod

# Or use Makefile
make deploy-dev
make deploy-prod
```

## 📖 Role-Based Architecture

The deployment logic is organized into the `tinyllama_deploy` role with modular tasks:

1. **preflight.yml** - Verify environment and tools
2. **terraform.yml** - Read Terraform state
3. **configure_cluster.yml** - Configure kubectl
4. **prerequisites.yml** - Check dependencies
5. **namespace.yml** - Namespace management
6. **deploy.yml** - Deploy model
7. **verify.yml** - Verify health
8. **test.yml** - Test endpoint
9. **summary.yml** - Display summary

## 🎯 Usage

```bash
# Basic deployment
ansible-playbook site.yml -i inventory -e deploy_environment=prod

# With tags
ansible-playbook site.yml -i inventory -e deploy_environment=prod --tags deploy
ansible-playbook site.yml -i inventory -e deploy_environment=prod --tags verify

# Cleanup
ansible-playbook cleanup.yml -i inventory -e deploy_environment=prod
```

## ⚙️ Configuration

Variables are organized by precedence:
- `roles/tinyllama_deploy/defaults/main.yml` - Lowest priority
- `group_vars/all.yml` - Global variables
- `group_vars/{dev,prod}.yml` - Environment-specific
- Command line `-e` - Highest priority

## 📚 Documentation

See `README.md.old` for full documentation including:
- Detailed usage examples
- Configuration options
- Troubleshooting guide
- Best practices explanation

---

**Ready to deploy?** Run `make deploy-dev` 🚀
