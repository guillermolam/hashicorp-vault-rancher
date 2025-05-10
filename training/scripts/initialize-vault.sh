#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Initializing Vault...${NC}"

# Wait for Vault pod to become available
VAULT_POD=$(kubectl -n vault get pods -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Check if Vault is already initialized
INITIALIZED=$(kubectl -n vault exec $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.initialized' 2>/dev/null || echo "false")

if [ "$INITIALIZED" == "true" ]; then
  echo -e "${YELLOW}Vault is already initialized.${NC}"
else
  echo -e "${YELLOW}Initializing Vault...${NC}"
  
  # Initialize Vault
  INIT_RESPONSE=$(kubectl -n vault exec $VAULT_POD -- vault operator init -format=json -key-shares=1 -key-threshold=1)
  
  # Extract root token and unseal key
  UNSEAL_KEY=$(echo $INIT_RESPONSE | jq -r '.unseal_keys_b64[0]')
  ROOT_TOKEN=$(echo $INIT_RESPONSE | jq -r '.root_token')
  
  # Save the credentials
  mkdir -p ~/.vault
  echo "Root Token: $ROOT_TOKEN" > ~/.vault/credentials
  echo "Unseal Key: $UNSEAL_KEY" >> ~/.vault/credentials
  chmod 600 ~/.vault/credentials
  
  echo -e "${GREEN}Vault initialized successfully.${NC}"
  echo -e "${GREEN}Credentials saved to ~/.vault/credentials${NC}"
fi

# Check if Vault is sealed
SEALED=$(kubectl -n vault exec $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.sealed' 2>/dev/null || echo "true")

if [ "$SEALED" == "true" ]; then
  echo -e "${YELLOW}Unsealing Vault...${NC}"
  
  # Get unseal key if not already extracted
  if [ -z "$UNSEAL_KEY" ]; then
    UNSEAL_KEY=$(grep "Unseal Key:" ~/.vault/credentials | cut -d' ' -f3)
  fi
  
  # Unseal Vault
  kubectl -n vault exec $VAULT_POD -- vault operator unseal $UNSEAL_KEY
  
  echo -e "${GREEN}Vault unsealed successfully.${NC}"
else
  echo -e "${YELLOW}Vault is already unsealed.${NC}"
fi

# Get root token if not already extracted
if [ -z "$ROOT_TOKEN" ]; then
  ROOT_TOKEN=$(grep "Root Token:" ~/.vault/credentials | cut -d' ' -f3)
fi

# Create a config file for the CLI
cat > ~/.vault/config << EOF
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$ROOT_TOKEN
EOF

# Store root token in Kubernetes secret for Windows access
kubectl -n vault create secret generic vault-token --from-literal=root_token=$ROOT_TOKEN --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}Vault is ready to use!${NC}"
echo -e "${GREEN}To use Vault CLI, run:${NC}"
echo -e "  ${YELLOW}source ~/.vault/config${NC}"
echo -e "${GREEN}Vault UI is accessible at:${NC}"
echo -e "  ${YELLOW}http://localhost:8201${NC} (after port-forwarding)"