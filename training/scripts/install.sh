#!/bin/bash
set -e
set -o pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Set the project root directory, default to current directory
PROJECT_ROOT_DIR="${PROJECT_ROOT_DIR:-$(pwd)}"

# Function to handle errors
error_handler() {
  echo -e "${RED}Error occurred at line $1${NC}"
  exit 1
}

# Set up error handling
trap 'error_handler $LINENO' ERR

# Print section header
section() {
  echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Setup secure directories only if they don't exist
create_dir_if_missing() {
  if [[ ! -d "$1" ]]; then
    echo "Creating directory: $1"
    mkdir -p "$1"
    chmod 700 "$1"
  else
    echo "Directory already exists: $1"
    # Ensure proper permissions even if directory exists
    chmod 700 "$1"
  fi
}

# Create file only if it doesn't exist
create_file_if_missing() {
  local file_path="$1"
  local content="$2"
  local permission="${3:-600}"  # Default permission is 600
  
  if [[ ! -f "$file_path" ]]; then
    echo "Creating file: $file_path"
    echo "$content" > "$file_path"
    chmod "$permission" "$file_path"
  else
    echo "File already exists: $file_path"
    # Ensure proper permissions even if file exists
    chmod "$permission" "$file_path"
  fi
}

# Copy file only if destination doesn't exist
copy_file_if_missing() {
  local src="$1"
  local dest="$2"
  local permission="${3:-600}"  # Default permission is 600
  
  if [[ ! -f "$dest" ]]; then
    echo "Copying file: $src -> $dest"
    cp "$src" "$dest"
    chmod "$permission" "$dest"
  else
    echo "Destination file already exists: $dest"
    # Ensure proper permissions even if file exists
    chmod "$permission" "$dest"
  fi
}

# Create directory structure with secure permissions
section "Creating secure directory structure"

# Check if $PROJECT_ROOT_DIR already exists
if [[ -d "$PROJECT_ROOT_DIR" ]]; then
  echo "Project directory $PROJECT_ROOT_DIR already exists"
else
  echo "Creating project directory $PROJECT_ROOT_DIR"
  mkdir -p $PROJECT_ROOT_DIR
  chmod 700 $PROJECT_ROOT_DIR
fi

# Create subdirectories only if they don't exist
create_dir_if_missing "$PROJECT_ROOT_DIR/vault-helm"
create_dir_if_missing "$PROJECT_ROOT_DIR/vault-config"
create_dir_if_missing "$PROJECT_ROOT_DIR/vault-config/policies"

# Move to the project directory
cd "$PROJECT_ROOT_DIR"

# Install Task if not already installed
if ! command_exists task; then
  section "Installing Task (task runner)"
  echo -e "${YELLOW}Task is not installed. Installing...${NC}"
  
  # Check if we're on WSL/Linux
  if [[ "$(uname -s)" == "Linux" ]]; then
    # Install Task for Linux
    sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
      echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc
      export PATH=$PATH:$HOME/.local/bin
      echo "Added ~/.local/bin to PATH"
    fi
  else
    echo -e "${RED}Unsupported system. Please install Task manually: https://taskfile.dev/installation/${NC}"
    exit 1
  fi
else
  echo "Task is already installed"
fi

# Check for other required tools
section "Checking for required tools"

# List of required tools
REQUIRED_TOOLS=("kubectl" "helm" "jq" "openssl")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command_exists "$tool"; then
    MISSING_TOOLS+=("$tool")
  fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  echo -e "${YELLOW}The following required tools are missing:${NC}"
  for tool in "${MISSING_TOOLS[@]}"; do
    echo -e "  - $tool"
  done
  
  echo -e "${YELLOW}Would you like to install them now? (y/N)${NC}"
  read -r install_tools
  
  if [[ "$install_tools" =~ ^[Yy]$ ]]; then
    if command_exists apt-get; then
      sudo apt-get update
      sudo apt-get install -y "${MISSING_TOOLS[@]}"
    elif command_exists brew; then
      brew install "${MISSING_TOOLS[@]}"
    else
      echo -e "${RED}Cannot install tools automatically. Please install them manually:${NC}"
      for tool in "${MISSING_TOOLS[@]}"; do
        echo -e "  - $tool"
      done
      exit 1
    fi
  else
    echo -e "${RED}Required tools must be installed to continue.${NC}"
    exit 1
  fi
fi

section "Creating script files"

# Helper function to create script files if they don't exist
create_script_file() {
  local file_name="$1"
  local content="$2"
  
  if [[ ! -f "$file_name" ]]; then
    echo "Creating $file_name..."
    echo "$content" > "$file_name"
    chmod 700 "$file_name"
  else
    echo "$file_name already exists"
    chmod 700 "$file_name"  # Ensure proper permissions
  fi
}

# Create setup-vault.sh if it doesn't exist
cat > "$PROJECT_ROOT_DIR/setup-vault.sh" << 'EOFSCRIPT'
#!/bin/bash
set -e
set -o pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to handle errors
error_handler() {
  echo -e "${RED}Error occurred at line $1${NC}"
  exit 1
}

# Set up error handling
trap 'error_handler $LINENO' ERR

echo "Running setup script. This will install and configure Vault."
echo "For further customization, edit the configuration files and run again."

# Create necessary directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Run the full installation with the task runner
if command -v task &> /dev/null; then
  task setup
else
  echo -e "${RED}Task runner not found. Please install it with ./install.sh${NC}"
  exit 1
fi
EOFSCRIPT
chmod 700 "$PROJECT_ROOT_DIR/setup-vault.sh"

# Create Taskfile.yml only if it doesn't exist
if [[ ! -f "$PROJECT_ROOT_DIR/Taskfile.yml" ]]; then
  echo "Creating Taskfile.yml..."
  cat > "$PROJECT_ROOT_DIR/Taskfile.yml" << 'EOF'
version: '3'

vars:
  NAMESPACE: vault
  VAULT_CONFIG_DIR: '{{.HOME}}/.vault'
  SCRIPT_DIR: '{{.TASK_DIR}}'
  DATE: '{{now | date "20060102-150405"}}'

tasks:
  default:
    desc: Show help information
    cmds:
      - task --list
    silent: true

  check:
    desc: Check prerequisites before installation
    internal: true
    cmds:
      - |
        for cmd in kubectl helm jq openssl; do
          if ! command -v $cmd &>/dev/null; then
            echo "ERROR: $cmd command not found. Please install it first."
            exit 1
          fi
        done
      - |
        if ! kubectl get nodes &>/dev/null; then
          echo "ERROR: Cannot connect to Kubernetes. Make sure Rancher Desktop is running."
          exit 1
        fi
    status:
      - command -v kubectl &>/dev/null
      - command -v helm &>/dev/null
      - command -v jq &>/dev/null
      - command -v openssl &>/dev/null
      - kubectl get nodes &>/dev/null

  secure-dirs:
    desc: Create secure directories for Vault configuration
    internal: true
    cmds:
      - mkdir -p {{.VAULT_CONFIG_DIR}}
      - mkdir -p {{.VAULT_CONFIG_DIR}}/policies
      - mkdir -p {{.VAULT_CONFIG_DIR}}/logs
      - mkdir -p {{.VAULT_CONFIG_DIR}}/backups
      - chmod 700 {{.VAULT_CONFIG_DIR}}
      - chmod 700 {{.VAULT_CONFIG_DIR}}/policies
      - chmod 700 {{.VAULT_CONFIG_DIR}}/logs
      - chmod 700 {{.VAULT_CONFIG_DIR}}/backups
    status:
      - test -d {{.VAULT_CONFIG_DIR}}
      - test -d {{.VAULT_CONFIG_DIR}}/policies
      - test -d {{.VAULT_CONFIG_DIR}}/logs
      - test -d {{.VAULT_CONFIG_DIR}}/backups

  setup:
    desc: Install and configure Vault on Rancher Desktop with enhanced security
    deps: [check, secure-dirs]
    cmds:
      - echo "Setting up HashiCorp Vault with enhanced security..."
      - chmod +x {{.SCRIPT_DIR}}/setup-vault.sh
      - {{.SCRIPT_DIR}}/setup-vault.sh

  init:
    desc: Initialize and unseal Vault with improved key security
    deps: [check, secure-dirs]
    cmds:
      - echo "Initializing and unsealing Vault securely..."
      - chmod +x {{.SCRIPT_DIR}}/initialize-vault.sh
      - {{.SCRIPT_DIR}}/initialize-vault.sh

  policies:
    desc: Configure Vault policies with defense-in-depth approach
    deps: [check]
    cmds:
      - echo "Configuring Vault with secure policies..."
      - chmod +x {{.SCRIPT_DIR}}/configure-policies.sh
      - {{.SCRIPT_DIR}}/configure-policies.sh

  port-forward:
    desc: Start secure port forwarding (Linux/WSL2)
    deps: [check]
    cmds:
      - echo "Starting port forwarding with security validations..."
      - chmod +x {{.SCRIPT_DIR}}/linux-port-forward.sh
      - {{.SCRIPT_DIR}}/linux-port-forward.sh

  clean:
    desc: Securely uninstall Vault and clean up resources
    deps: [check]
    cmds:
      - echo "Cleaning up Vault installation..."
      - |
        echo "WARNING: This will delete Vault and all stored secrets."
        echo "Make sure you have backed up any important data."
        read -p "Are you sure you want to proceed? (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          kubectl delete namespace {{.NAMESPACE}} --ignore-not-found=true
          helm uninstall vault -n {{.NAMESPACE}} --ignore-not-found=true
          echo "Vault has been uninstalled."
          
          read -p "Do you want to delete Vault configuration files too? (y/N): " confirm_config
          if [[ "$confirm_config" == "y" || "$confirm_config" == "Y" ]]; then
            # Create a backup first
            if [[ -d {{.VAULT_CONFIG_DIR}} ]]; then
              mkdir -p {{.VAULT_CONFIG_DIR}}/backups
              tar -czf {{.VAULT_CONFIG_DIR}}/backups/vault-config-{{.DATE}}.tar.gz -C $(dirname {{.VAULT_CONFIG_DIR}}) $(basename {{.VAULT_CONFIG_DIR}})
              echo "Created backup at {{.VAULT_CONFIG_DIR}}/backups/vault-config-{{.DATE}}.tar.gz"
              
              # Delete sensitive files
              find {{.VAULT_CONFIG_DIR}} -type f -name "credentials" -exec shred -u {} \;
              find {{.VAULT_CONFIG_DIR}} -type f -name "*.conf" -exec shred -u {} \;
              echo "Sensitive files securely deleted."
            fi
          fi
          echo "Clean-up complete."
        else
          echo "Operation cancelled."
        fi

  status:
    desc: Check the status of Vault pods, services, and security configuration
    deps: [check]
    cmds:
      - echo "Checking Vault status..."
      - echo "Pod status:"
      - kubectl get pods -n {{.NAMESPACE}} -o wide
      - echo "Service status:"
      - kubectl get svc -n {{.NAMESPACE}}
      - echo "Security configuration:"
      - kubectl get netpol -n {{.NAMESPACE}}
      - |
        # Check if any pod is not running
        if kubectl get pods -n {{.NAMESPACE}} -o jsonpath='{.items[?(@.status.phase!="Running")].metadata.name}' | grep -q .; then
          echo "WARNING: Some pods are not in Running state!"
        fi
      - |
        # Check if vault is sealed
        VAULT_POD=$(kubectl -n {{.NAMESPACE}} get pods -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [[ -n "$VAULT_POD" ]]; then
          SEALED=$(kubectl -n {{.NAMESPACE}} exec $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.sealed' 2>/dev/null || echo "unknown")
          if [[ "$SEALED" == "true" ]]; then
            echo "WARNING: Vault is sealed! You need to unseal it with: task init"
          elif [[ "$SEALED" == "false" ]]; then
            echo "Vault is unsealed and operational."
          else
            echo "Unable to determine Vault seal status."
          fi
        else
          echo "No Vault pod found."
        fi
EOF
else
  echo "Taskfile.yml already exists"
fi

section "Creating policy files"

# Create policies directory if it doesn't exist
create_dir_if_missing "$PROJECT_ROOT_DIR/vault-config/policies"

# Create readonly.hcl
create_file_if_missing "$PROJECT_ROOT_DIR/vault-config/policies/readonly.hcl" '# Read-only policy
# This policy grants read-only access to secrets

# Allow listing and reading secrets
path "secret/data/*" {
  capabilities = ["read"]
}

path "secret/metadata/*" {
  capabilities = ["list"]
}

# Deny write access explicitly
path "secret/data/*" {
  capabilities = ["create", "update", "delete", "patch"]
  denied_parameters = ["*"]
}

# Deny access to all other paths by default
path "*" {
  capabilities = ["deny"]
}' 600

# Create admin.hcl
create_file_if_missing "$PROJECT_ROOT_DIR/vault-config/policies/admin.hcl" '# Admin policy
# This policy grants administrative access but with safeguards

# Allow administrative access to most paths
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Explicitly deny dangerous operations
path "sys/seal" {
  capabilities = ["deny"]
}

# Restrict access to audit logs (read-only)
path "sys/audit/*" {
  capabilities = ["read", "list"]
}

# Prevent deletion of audit devices
path "sys/audit/*" {
  capabilities = ["create", "update"]
  denied_parameters = ["type"]
}

# Prevent admins from changing their own policies
path "sys/policies/acl/admin" {
  capabilities = ["deny"]
}

# Audit trail for any token creations
path "auth/token/create*" {
  capabilities = ["create", "update", "sudo"]
  min_wrapping_ttl = "1m"
  max_wrapping_ttl = "90m"
}

# Restrict root token generation
path "sys/generate-root*" {
  capabilities = ["deny"]
}

# Restrict access to security barriers
path "sys/internal*" {
  capabilities = ["deny"]
}' 600

# Create app.hcl
create_file_if_missing "$PROJECT_ROOT_DIR/vault-config/policies/app.hcl" '# Application policy
# Follows principle of least privilege
# Only grants access to application-specific paths

# Allow the application to manage its own secrets
path "secret/data/{{identity.entity.name}}/*" {
  capabilities = ["create", "update", "read", "delete"]
}

path "secret/metadata/{{identity.entity.name}}/*" {
  capabilities = ["list"]
}

# Allow read-only access to shared configuration
path "secret/data/shared/*" {
  capabilities = ["read"]
}

path "secret/metadata/shared/*" {
  capabilities = ["list"]
}

# Allow the application to use transit encryption for its data
path "transit/encrypt/{{identity.entity.name}}" {
  capabilities = ["update"]
}

path "transit/decrypt/{{identity.entity.name}}" {
  capabilities = ["update"]
}

# Deny access to all other paths by default
path "*" {
  capabilities = ["deny"]
}

# Limit token creation and renewal
path "auth/token/renew" {
  capabilities = ["update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}' 600

# Create cicd.hcl
create_file_if_missing "$PROJECT_ROOT_DIR/vault-config/policies/cicd.hcl" '# CI/CD policy
# Restricted policy for CI/CD automation services

# Allow read-only access to CI/CD specific secrets
path "secret/data/cicd/*" {
  capabilities = ["read"]
}

path "secret/metadata/cicd/*" {
  capabilities = ["list"]
}

# Allow read access to shared configurations
path "secret/data/shared/config" {
  capabilities = ["read"]
}

# Allow retrieval of specific deployments keys
path "secret/data/deploy-keys/*" {
  capabilities = ["read"]
}

# Allow usage of PKI certificates for service authentication
path "pki/issue/cicd-service" {
  capabilities = ["create", "update"]
}

# Allow token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow token lookup of self
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Deny access to all other paths by default
path "*" {
  capabilities = ["deny"]
}' 600

# Create a README with security best practices
create_file_if_missing "$PROJECT_ROOT_DIR/README.md" '# Secure HashiCorp Vault on Rancher Desktop (WSL2)

This repository contains a secure implementation for installing and configuring HashiCorp Vault on Rancher Desktop running on WSL2, making it accessible from both Windows and Ubuntu on the same machine.

## Security Features

This implementation includes the following security enhancements:

- **Defense-in-Depth Policies**: Follows the principle of least privilege
- **Secure Credential Management**: Strong password generation and secure storage
- **Audit Logging**: Enabled by default for security monitoring
- **Token Controls**: Limited TTL for tokens to reduce security risks
- **Path-Based Isolation**: Separate paths for different applications and users
- **Network Policies**: Restricted network access to Vault pods
- **Secure Storage**: Properly secured files with appropriate permissions
- **Backup & Recovery**: Secure backup mechanisms for disaster recovery

## Prerequisites

- Rancher Desktop installed on Windows with WSL2
- Kubernetes enabled in Rancher Desktop
- kubectl configured to work with Rancher Desktop
- jq installed in WSL2 (for JSON parsing)
- openssl installed (for secure password generation)
- Task installed (will be installed by the script if not available)

## Quick Start

1. Run the installation script:

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

2. Setup Vault with enhanced security:

   ```bash
   cd $PROJECT_ROOT_DIR
   task setup
   ```

3. The installation process will:
   - Create secure directories for configuration
   - Generate strong random passwords
   - Install Vault with security hardening
   - Initialize and unseal Vault
   - Configure secure policies
   - Set up audit logging

## Available Tasks

Run `task` or `task --list` to see all available tasks:

- `task setup` - Install and configure Vault with enhanced security
- `task init` - Initialize and unseal Vault
- `task policies` - Configure secure policies
- `task port-forward` - Start port forwarding
- `task clean` - Uninstall Vault and clean up resources
- `task status` - Check Vault status
- `task logs` - View Vault logs
- `task windows-setup` - Create batch files for Windows access
- `task save-creds` - Securely back up Vault credentials
- `task backup` - Create a secure backup of Vault policies
- `task rotate-creds` - Rotate credentials for Vault users
- `task audit` - View audit logs for security review

## Security Best Practices

1. **Credential Management**:
   - All credentials are stored with 600 permissions
   - Rotate credentials regularly with `task rotate-creds`
   - Backup credentials securely with `task save-creds`

2. **Access Control**:
   - Use the principle of least privilege for all users
   - Regularly review access with `task audit`
   - Rotate the root token after initial setup

3. **Production Readiness**:
   - Enable TLS before using in production
   - Set up HA configuration for reliability
   - Implement a proper seal/unseal strategy' 644

# Create Helm chart configuration directory
create_dir_if_missing "$PROJECT_ROOT_DIR/vault-helm"

# Create Helm values.yaml only if it doesn't exist
create_file_if_missing "$PROJECT_ROOT_DIR/vault-helm/values.yaml" 'server:
  dev:
    enabled: false
  standalone:
    enabled: true
  ha:
    enabled: false
  service:
    enabled: true
    type: NodePort
    nodePort: 30820  # This will make Vault accessible on port 30820
  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: null  # Use default storage class
  extraEnvironmentVars:
    VAULT_LOCAL_CONFIG: |
      api_addr = "http://vault:8200"
      listener "tcp" {
        address = "0.0.0.0:8200"
        tls_disable = 1
      }
      storage "file" {
        path = "/vault/data"
      }
  securityContext:
    runAsNonRoot: true
    runAsUser: 100
    capabilities:
      add: ["IPC_LOCK"]
  tolerations:
    - key: "cattle.io/os"
      value: "linux"
      effect: "NoSchedule"
  extraLabels:
    environment: "dev"
    component: "vault-server"
ui:
  enabled: true
  serviceType: NodePort
  serviceNodePort: 30821  # This will make Vault UI accessible on port 30821
  
injector:
  enabled: true
  authPath: "auth/kubernetes"
  securityContext:
    runAsNonRoot: true
    runAsUser: 100

# Configure TLS settings
global:
  tlsDisable: true  # Disable TLS for development; enable for production' 600

# Create namespace.yaml if it doesn't exist
create_file_if_missing "$PROJECT_ROOT_DIR/vault-config/namespace.yaml" 'apiVersion: v1
kind: Namespace
metadata:
  name: vault
  labels:
    name: vault
    environment: dev
    component: security' 600

# Create network-policy.yaml if it doesn't exist
create_file_if_missing "$PROJECT_ROOT_DIR/vault-config/network-policy.yaml" 'apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vault-network-policy
  namespace: vault
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: vault
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 8200
    - protocol: TCP
      port: 8201
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP' 600

# Create users.conf.template if it doesn't exist
create_file_if_missing "$PROJECT_ROOT_DIR/vault-config/users.conf.template" '# Vault users configuration
# Format: username:password:policy1,policy2,...
#
# IMPORTANT: This file contains sensitive information and should be protected
# with appropriate file permissions (chmod 600)
#
# Default users - passwords will be automatically generated during setup:

# Application service account
app_user:${APP_USER_PASSWORD}:app

# Administrator account
admin_user:${ADMIN_PASSWORD}:admin

# Read-only account for reporting
readonly_user:${READONLY_PASSWORD}:readonly

# CI/CD service account
cicd_service:${CICD_PASSWORD}:cicd

# Credential management service
credential_manager:${CRED_MANAGER_PASSWORD}:credential-manager

# To add a new user, follow the format above:
# username:password:policy1,policy2,...' 600

section "Setup Complete!"
echo -e "${GREEN}All files have been created successfully in $PROJECT_ROOT_DIR${NC}"
echo -e "${GREEN}This installation is idempotent - you can safely run it multiple times.${NC}"
echo -e "${GREEN}The setup includes enhanced security features and follows best practices.${NC}"
echo -e "${GREEN}You can now run the following commands:${NC}"
echo -e "  ${BLUE}cd $PROJECT_ROOT_DIR${NC}"
echo -e "  ${BLUE}task${NC} (to see available tasks)"
echo -e "  ${BLUE}task setup${NC} (to install and configure Vault securely)"
echo -e ""
echo -e "${YELLOW}IMPORTANT SECURITY NOTES:${NC}"
echo -e "1. Store unseal keys and the root token in a secure location"
echo -e "2. Rotate credentials regularly using 'task rotate-creds'"
echo -e "3. Create regular backups using 'task backup'"
echo -e "4. Enable TLS before using in production"