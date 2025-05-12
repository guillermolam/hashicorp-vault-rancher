#!/bin/bash
set -e
set -o pipefail

# Colors for output
GREEN='\033[0;32m'
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

# Function to securely retrieve credentials from file
get_credentials() {
  local credential_file="$1"
  local credential_name="$2"
  
  if [[ ! -f "$credential_file" ]]; then
    echo -e "${RED}Credential file not found: $credential_file${NC}"
    exit 1
  fi
  
  # Use grep with word boundaries to avoid partial matches
  local value=$(grep -w "^$credential_name:" "$credential_file" | cut -d ':' -f2- | tr -d ' ')
  
  if [[ -z "$value" ]]; then
    echo -e "${RED}Credential $credential_name not found in $credential_file${NC}"
    exit 1
  fi
  
  echo "$value"
}

# Securely read policy files
read_policy_file() {
  local policy_dir="$1"
  local policy_name="$2"
  
  local policy_file="${policy_dir}/${policy_name}.hcl"
  
  if [[ ! -f "$policy_file" ]]; then
    echo -e "${RED}Policy file not found: $policy_file${NC}"
    exit 1
  fi
  
  cat "$policy_file"
}

echo -e "${YELLOW}Configuring Vault with secure policies...${NC}"

# Config directory for policies and credentials
CONFIG_DIR="${HOME}/.vault"
POLICY_DIR="${CONFIG_DIR}/policies"
CREDS_FILE="${CONFIG_DIR}/credentials"
VAULT_CONFIG="${CONFIG_DIR}/config"

# Create necessary directories with secure permissions
mkdir -p "${POLICY_DIR}"
chmod 700 "${CONFIG_DIR}"
chmod 700 "${POLICY_DIR}"

# Get environment variables
if [[ -f "$VAULT_CONFIG" ]]; then
  # Source with a subshell to avoid exposing variables
  source "$VAULT_CONFIG"
else
  echo -e "${RED}Vault config not found at $VAULT_CONFIG. Please run initialize-vault.sh first.${NC}"
  exit 1
fi

# Validate VAULT_ADDR and VAULT_TOKEN are set
if [[ -z "$VAULT_ADDR" ]]; then
  echo -e "${RED}VAULT_ADDR environment variable is not set.${NC}"
  exit 1
fi

if [[ -z "$VAULT_TOKEN" ]]; then
  echo -e "${RED}VAULT_TOKEN environment variable is not set.${NC}"
  exit 1
fi

# Make sure port forwarding is active
if ! curl -s --connect-timeout 5 "$VAULT_ADDR/v1/sys/health" > /dev/null; then
  echo -e "${RED}Vault is not accessible at $VAULT_ADDR. Please ensure port forwarding is active.${NC}"
  echo -e "${YELLOW}Run ./linux-port-forward.sh in another terminal.${NC}"
  exit 1
fi

# Create policy files in a secure directory
echo -e "${YELLOW}Creating policy files...${NC}"

# Create a basic read-only policy
cat > "${POLICY_DIR}/readonly.hcl" << EOF
# Read-only policy
path "secret/*" {
  capabilities = ["read", "list"]
}
EOF

# Create admin policy
cat > "${POLICY_DIR}/admin.hcl" << EOF
# Admin policy
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Explicitly deny dangerous operations
path "sys/seal" {
  capabilities = ["deny"]
}
EOF

# Create app policy
cat > "${POLICY_DIR}/app.hcl" << EOF
# Application policy - least privilege approach
path "secret/data/{{identity.entity.name}}/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

path "secret/metadata/{{identity.entity.name}}/*" {
  capabilities = ["list"]
}

# Deny access to all other paths by default
path "*" {
  capabilities = ["deny"]
}
EOF

# Create CI/CD policy
cat > "${POLICY_DIR}/cicd.hcl" << EOF
# CI/CD policy
path "secret/data/cicd/*" {
  capabilities = ["read"]
}

# Deny access to all other paths by default
path "*" {
  capabilities = ["deny"]
}
EOF

# Create a rotating-credentials policy
cat > "${POLICY_DIR}/credential-manager.hcl" << EOF
# Credentials Manager policy
path "secret/data/credentials/*" {
  capabilities = ["create", "update", "read", "delete"]
}

path "secret/metadata/credentials/*" {
  capabilities = ["list"]
}

# Allow generating dynamic credentials
path "database/creds/*" {
  capabilities = ["read"]
}
EOF

# Set secure permissions for policy files
chmod 600 ${POLICY_DIR}/*.hcl

# Read configuration from a config file
USERS_CONFIG="${CONFIG_DIR}/users.conf"

if [[ ! -f "$USERS_CONFIG" ]]; then
  echo -e "${YELLOW}Creating default users configuration file...${NC}"
  cat > "$USERS_CONFIG" << EOF
# Vault users configuration
# Format: username:password:policy1,policy2,...
# Example: john:securePassword123:app,readonly

app_user:$(openssl rand -base64 16):app
admin_user:$(openssl rand -base64 16):admin
readonly_user:$(openssl rand -base64 16):readonly
cicd_service:$(openssl rand -base64 16):cicd
credential_manager:$(openssl rand -base64 16):credential-manager
EOF
  chmod 600 "$USERS_CONFIG"
  echo -e "${GREEN}Created users configuration with secure random passwords at $USERS_CONFIG${NC}"
fi

# Write policies to Vault
echo -e "${YELLOW}Writing policies to Vault...${NC}"
for policy_file in "${POLICY_DIR}"/*.hcl; do
  policy_name=$(basename "$policy_file" .hcl)
  echo -e "Applying $policy_name policy..."
  vault policy write "$policy_name" "$policy_file"
done

# Check if KV v2 secret engine is already enabled
KV_ENABLED=$(vault secrets list -format=json | jq -r 'has("secret/")')
if [[ "$KV_ENABLED" != "true" ]]; then
  # Enable the KV v2 secrets engine
  echo -e "${YELLOW}Enabling KV v2 secrets engine...${NC}"
  vault secrets enable -path=secret kv-v2
else
  echo -e "${YELLOW}KV v2 secrets engine already enabled at path 'secret/'${NC}"
fi

# Enable userpass auth method if not already enabled
AUTH_ENABLED=$(vault auth list -format=json | jq -r 'has("userpass/")')
if [[ "$AUTH_ENABLED" != "true" ]]; then
  echo -e "${YELLOW}Enabling userpass auth method...${NC}"
  vault auth enable userpass
else
  echo -e "${YELLOW}Userpass auth method already enabled${NC}"
fi

# Create users from configuration file
echo -e "${YELLOW}Creating Vault users...${NC}"
while IFS=: read -r username password policies || [[ -n "$username" ]]; do
  # Skip comment lines and empty lines
  if [[ "$username" =~ ^# ]] || [[ -z "$username" ]]; then
    continue
  fi
  
  # Create the user with the specified password and policies
  echo -e "Creating user $username with policies: $policies"
  vault write auth/userpass/users/"$username" \
    password="$password" \
    policies="$policies"
done < "$USERS_CONFIG"

# Create some example secrets with secure permissions
echo -e "${YELLOW}Creating example secrets...${NC}"

# Create a secure random API key
API_KEY=$(openssl rand -hex 16)
API_SECRET=$(openssl rand -hex 32)

# Store example secrets
vault kv put secret/example/config \
  environment="development" \
  debug="false" \
  log_level="info"

vault kv put secret/example/credentials \
  api_key="$API_KEY" \
  api_secret="$API_SECRET"

# Create user-specific secrets for app_user
vault kv put secret/data/app_user/config \
  username="app_service" \
  environment="development"

# Setup Vault audit logs
AUDIT_ENABLED=$(vault audit list -format=json | jq -r 'has("file/")')
if [[ "$AUDIT_ENABLED" != "true" ]]; then
  echo -e "${YELLOW}Enabling audit logging...${NC}"
  mkdir -p "${CONFIG_DIR}/logs"
  chmod 700 "${CONFIG_DIR}/logs"
  vault audit enable file file_path="${CONFIG_DIR}/logs/vault_audit.log"
else
  echo -e "${YELLOW}Audit logging already enabled${NC}"
fi

# Configure token settings for increased security
echo -e "${YELLOW}Configuring token settings...${NC}"
vault write sys/auth/token/tune \
  default_lease_ttl=1h \
  max_lease_ttl=24h

# Rotate the root token (optional)
if [[ -z "${SKIP_ROOT_ROTATION}" ]]; then
  echo -e "${YELLOW}Would you like to rotate the root token? (y/N)${NC}"
  read -r rotate_response
  
  if [[ "$rotate_response" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Creating a new token with root policies...${NC}"
    NEW_TOKEN=$(vault token create -policy="admin" -format=json | jq -r '.auth.client_token')
    
    # Update the config file with the new token
    sed -i.bak "s/^export VAULT_TOKEN=.*$/export VAULT_TOKEN=$NEW_TOKEN/" "$VAULT_CONFIG"
    chmod 600 "$VAULT_CONFIG"
    
    echo -e "${GREEN}Root token rotated. New admin token saved to $VAULT_CONFIG${NC}"
    echo -e "${YELLOW}You should revoke the old root token manually after verifying the new token works.${NC}"
    echo -e "${YELLOW}Run: VAULT_TOKEN=<old-token> vault token revoke <old-token>${NC}"
  fi
fi

echo -e "${GREEN}Vault configuration completed successfully!${NC}"
echo -e "${GREEN}Created:${NC}"
echo -e "  - Secure policy files in ${POLICY_DIR}"
echo -e "  - Multiple policies with least-privilege approach"
echo -e "  - Users with strong passwords in $USERS_CONFIG"
echo -e "  - Audit logging enabled at ${CONFIG_DIR}/logs/vault_audit.log"
echo -e "  - Example secrets"

echo -e "\n${YELLOW}To log in as a user:${NC}"
echo -e "  vault login -method=userpass username=<username>"
echo -e "  # You will be prompted for the password"
echo -e "\n${YELLOW}User credentials are stored in:${NC} $USERS_CONFIG"