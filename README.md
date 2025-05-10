# HashiCorp Vault on Rancher Desktop (WSL2)

This repository contains all the necessary scripts and configurations to install and configure HashiCorp Vault on Rancher Desktop running on WSL2, making it accessible from both Windows and Ubuntu on the same machine.

## Prerequisites

- Rancher Desktop installed on Windows with WSL2
- Kubernetes enabled in Rancher Desktop
- kubectl configured to work with Rancher Desktop
- jq installed in WSL2 (for JSON parsing)

## Quick Start

1. Clone this repository or download all the files to your local machine.
2. Open a WSL2 terminal and navigate to the directory containing the scripts.
3. Make the setup script executable:

   ```bash
   chmod +x setup-vault.sh
   ```

4. Run the setup script:

   ```bash
   ./setup-vault.sh
   ```

5. The script will:
   - Check for prerequisites
   - Create necessary directories and configuration files
   - Install Vault using Helm
   - Initialize and unseal Vault
   - Configure access for both Windows and Ubuntu

## Accessing Vault

### From Ubuntu (WSL2)

1. Start port forwarding:

   ```bash
   ./linux-port-forward.sh
   ```

2. Load Vault environment variables:

   ```bash
   source ~/.vault/config
   ```

3. Access Vault using CLI:

   ```bash
   vault status
   ```

4. Access Vault UI in your browser: http://localhost:8201

### From Windows

1. Start port forwarding (open Command Prompt or PowerShell):

   ```
   vault-port-forward.bat
   ```

2. Load Vault environment variables:

   ```
   vault-env.bat
   ```

3. Access Vault UI in your browser: http://localhost:8201

## Files Included

- `setup-vault.sh`: Main setup script
- `values.yaml`: Helm chart values for Vault
- `initialize-vault.sh`: Script to initialize and unseal Vault
- `linux-port-forward.sh`: Port forwarding script for Ubuntu/WSL2
- `vault-port-forward.bat`: Port forwarding script for Windows
- `vault-env.bat`: Script to set Vault environment variables in Windows

## Vault Credentials

After installation, Vault credentials (root token and unseal key) are stored in:

- Ubuntu/WSL2: `~/.vault/credentials`
- Windows: `%USERPROFILE%\.vault\credentials.txt`

## Troubleshooting

## Architecture

```bash
vault-rancher-deployment/  # Root directory for the entire project
├── terraform/  # All Terraform configuration files
│   ├── modules/  # Reusable Terraform modules organized by component
│   │   ├── vault/  # Module for Vault server deployment and configuration
│   │   │   ├── main.tf  # Primary Terraform configuration for Vault deployment
│   │   │   ├── variables.tf  # Input variables for the Vault module
│   │   │   ├── outputs.tf  # Outputs exposed by the Vault module
│   │   │   └── tests/  # Unit tests specific to the Vault module
│   │   │       └── vault_test.go  # Go tests using Terratest for Vault module validation
│   │   ├── certificates/  # Module for managing TLS certificates
│   │   │   ├── main.tf  # Certificate creation and management logic
│   │   │   ├── variables.tf  # Input variables for certificate configuration
│   │   │   ├── outputs.tf  # Certificate outputs (paths, references)
│   │   │   └── tests/  # Unit tests for certificates module
│   │   │       └── certificates_test.go  # Tests for certificate creation and validation
│   │   └── auth/  # Module for Vault authentication (Auth0/OIDC)
│   │       ├── main.tf  # Auth configuration with Okta Auth0 integration
│   │       ├── variables.tf  # Auth-specific variables (client IDs, URLs)
│   │       ├── outputs.tf  # Auth configuration outputs
│   │       └── tests/  # Unit tests for auth module
│   │           └── auth_test.go  # Tests for auth configuration validation
│   ├── environments/  # Environment-specific Terraform configurations
│   │   ├── dev-kind/  # Development environment using Kind
│   │   │   ├── main.tf  # Dev environment main configuration using modules
│   │   │   ├── variables.tf  # Variables specific to dev environment
│   │   │   └── terraform.tfvars  # Variable values for dev environment
│   │   └── prod-rancher/  # Production environment using Rancher
│   │       ├── main.tf  # Production configuration with HA setup
│   │       ├── variables.tf  # Production-specific variables
│   │       └── terraform.tfvars  # Production variable values
│   └── tests/  # Integration tests across modules
│       └── integration_test.go  # Tests that validate complete deployment
├── helm/  # Helm chart configurations and customizations
│   ├── values/  # Custom values files for different environments
│   │   ├── kind.yaml  # Helm values optimized for Kind development
│   │   └── rancher.yaml  # Helm values optimized for Rancher production
│   └── tests/  # Tests for Helm chart validation
│       └── helm_test.sh  # Shell script to validate Helm template rendering
├── kind/  # Kind-specific configuration for dev environment
│   ├── config.yaml  # Kind cluster configuration (nodes, networking)
│   └── setup-kind.sh  # Script to create and configure Kind cluster
├── certificates/  # Storage for certificates and keys
│   ├── ca/  # Certificate Authority certificates
│   ├── dev/  # Development environment certificates (possibly self-signed)
│   └── prod/  # Production certificates (possibly from real CA)
├── .github/  # GitHub-related configuration
│   ├── workflows/
│   │   ├── unit-tests.yml  # Workflow for running unit tests on modules
│   │   ├── kind-tests.yml  # Workflow for testing in Kind environment
│   │   ├── rancher-tests.yml  # Workflow for testing in Rancher
│   │   ├── deploy.yml  # Workflow for production deployment
│   │   └── sbom.yml  # Workflow for SBOM generation with CycloneDX
│   └── actions/
│       ├── setup-kind/
│       │   ├── action.yml  # Action metadata and inputs
│       │   └── Dockerfile  # Container definition for Kind setup
│       ├── terraform-test/
│       │   ├── action.yml  # Action metadata and inputs
│       │   └── Dockerfile  # Container with Terraform and testing tools
│       ├── helm-test/
│       │   ├── action.yml  # Action metadata and inputs
│       │   └── Dockerfile  # Container with Helm and testing tools
│       └── cyclonedx-bom/
│           ├── action.yml  # Action metadata for SBOM generation
│           └── Dockerfile  # Container with CycloneDX tools
├── sbom/  # Directory for SBOM-related files
│   ├── config/  # Configuration for CycloneDX tools
│   │   ├── cyclonedx-terraform.json  # Configuration for Terraform scanning
│   │   └── cyclonedx-helm.json  # Configuration for Helm scanning
│   └── templates/  # Templates for SBOM generation
│       ├── terraform-component.json  # Template for Terraform components
│       └── helm-component.json  # Template for Helm components
├── .task/  # New: Taskfile modules and includes
│   ├── terraform.yml  # Terraform-specific tasks
│   ├── helm.yml  # Helm-specific tasks
│   ├── kind.yml  # Kind-specific tasks
│   ├── rancher.yml  # Rancher-specific tasks
│   ├── test.yml  # Testing tasks
│   ├── sbom.yml  # SBOM generation tasks
│   └── ci.yml  # CI-related tasks
├── Taskfile.yml  # New: Main Taskfile for lifecycle management
├── .actrc  # Configuration for running GitHub Actions locally with Act
├── act-secrets.env  # Local secrets file for Act (gitignored)
├── .gitignore  # Git ignore file
└── README.md  # Project documentation and instructions
```

## Project Structure Explanation for vault-rancher-deployment

```bash
vault-rancher-deployment/  # Root directory for the entire project
```
## Terraform Configuration

```bash
├── terraform/  # All Terraform configuration files
│   ├── modules/  # Reusable Terraform modules organized by component
│   │   ├── vault/  # Module for Vault server deployment and configuration
│   │   │   ├── main.tf  # Primary Terraform configuration for Vault deployment
│   │   │   ├── variables.tf  # Input variables for the Vault module
│   │   │   ├── outputs.tf  # Outputs exposed by the Vault module
│   │   │   └── tests/  # Unit tests specific to the Vault module
│   │   │       └── vault_test.go  # Go tests using Terratest for Vault module validation
│   │   ├── certificates/  # Module for managing TLS certificates
│   │   │   ├── main.tf  # Certificate creation and management logic
│   │   │   ├── variables.tf  # Input variables for certificate configuration
│   │   │   ├── outputs.tf  # Certificate outputs (paths, references)
│   │   │   └── tests/  # Unit tests for certificates module
│   │   │       └── certificates_test.go  # Tests for certificate creation and validation
│   │   └── auth/  # Module for Vault authentication (Auth0/OIDC)
│   │       ├── main.tf  # Auth configuration with Okta Auth0 integration
│   │       ├── variables.tf  # Auth-specific variables (client IDs, URLs)
│   │       ├── outputs.tf  # Auth configuration outputs
│   │       └── tests/  # Unit tests for auth module
│   │           └── auth_test.go  # Tests for auth configuration validation
│   ├── environments/  # Environment-specific Terraform configurations
│   │   ├── dev-kind/  # Development environment using Kind
│   │   │   ├── main.tf  # Dev environment main configuration using modules
│   │   │   ├── variables.tf  # Variables specific to dev environment
│   │   │   └── terraform.tfvars  # Variable values for dev environment
│   │   └── prod-rancher/  # Production environment using Rancher
│   │       ├── main.tf  # Production configuration with HA setup
│   │       ├── variables.tf  # Production-specific variables
│   │       └── terraform.tfvars  # Production variable values
│   └── tests/  # Integration tests across modules
│       └── integration_test.go  # Tests that validate complete deployment
```
## Helm Configuration

```bash
├── helm/  # Helm chart configurations and customizations
│   ├── values/  # Custom values files for different environments
│   │   ├── kind.yaml  # Helm values optimized for Kind development
│   │   └── rancher.yaml  # Helm values optimized for Rancher production
│   └── tests/  # Tests for Helm chart validation
│       └── helm_test.sh  # Shell script to validate Helm template rendering
Kind Configuration
├── kind/  # Kind-specific configuration for dev environment
│   ├── config.yaml  # Kind cluster configuration (nodes, networking)
│   └── setup-kind.sh  # Script to create and configure Kind cluster
Certificate Management
├── certificates/  # Storage for certificates and keys
│   ├── ca/  # Certificate Authority certificates
│   ├── dev/  # Development environment certificates (possibly self-signed)
│   └── prod/  # Production certificates (possibly from real CA)
GitHub Actions Configuration
├── .github/  # GitHub-related configuration
│   ├── workflows/  # GitHub Actions workflow definitions
│   │   ├── unit-tests.yml  # Workflow for running unit tests on modules
│   │   ├── kind-tests.yml  # Workflow for testing in Kind environment
│   │   ├── rancher-tests.yml  # Workflow for testing in Rancher
│   │   └── deploy.yml  # Workflow for production deployment
│   └── actions/  # Custom GitHub Actions
│       ├── setup-kind/  # Action for setting up Kind cluster
│       │   ├── action.yml  # Action metadata and inputs
│       │   └── Dockerfile  # Container definition for Kind setup
│       ├── terraform-test/  # Action for Terraform testing
│       │   ├── action.yml  # Action metadata and inputs
│       │   └── Dockerfile  # Container with Terraform and testing tools
│       └── helm-test/  # Action for Helm testing
│           ├── action.yml  # Action metadata and inputs
│           └── Dockerfile  # Container with Helm and testing tools
```
## Scripts and Configuration

```bash 
├── scripts/  # Utility scripts for local development and testing
│   ├── kind-setup.sh  # Script to set up Kind cluster locally
│   ├── rancher-setup.sh  # Script to configure Rancher environment
│   ├── test-kind.sh  # Run tests in Kind environment
│   └── test-rancher.sh  # Run tests in Rancher environment
├── .actrc  # Configuration for running GitHub Actions locally with Act
├── act-secrets.env  # Local secrets file for Act (gitignored)
└── README.md  # Project documentation and instructions
```

This structure follows infrastructure as code best practices with:

- Modular components that can be developed and tested independently
- Separation of environments (dev vs prod)
- Comprehensive test coverage at multiple levels
- CI/CD automation with GitHub Actions
- Local development capabilities with Kind and Act0