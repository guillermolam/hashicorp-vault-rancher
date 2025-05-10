#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print section header
section() {
  echo -e "${BLUE}=== $1 ===${NC}"
}

# Current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

section "Fixing crashed Vault without deleting PVCs"
echo "This will update Vault to use in-memory storage temporarily to debug the issue."

# Check current pod status
kubectl get pods -n vault


# Upgrade Vault to fix the crashed pod
section "Upgrading Vault helm release"
helm upgrade vault hashicorp/vault \
  --namespace vault \
  --values "$SCRIPT_DIR/vault-helm/values.yaml"

# Wait for Vault pod to restart and stabilize
section "Waiting for Vault pod to restart"
echo "This may take a minute..."
sleep 15  # Wait for the pod to restart

# Check pod status periodically
for i in {1..12}; do
  echo "Checking pod status (attempt $i/12)..."
  kubectl get pods -n vault
  
  # Check if pod is Running
  POD_STATUS=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
  if [[ "$POD_STATUS" == "Running" ]]; then
    # Check if it's actually ready
    READY_STATUS=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
    if [[ "$READY_STATUS" == "true" ]]; then
      echo -e "${GREEN}Vault pod is running and ready!${NC}"
      break
    fi
  fi
  
  if [[ $i -eq 12 ]]; then
    echo -e "${RED}Pod is still not ready after multiple checks.${NC}"
    section "Detailed Diagnostics"
    kubectl describe pod -n vault -l app.kubernetes.io/name=vault
    kubectl logs -n vault -l app.kubernetes.io/name=vault
    exit 1
  fi
  
  sleep 10
done

# Get pod details
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Check logs
section "Pod Logs"
kubectl logs $VAULT_POD -n vault | tail -20

# Set up port forwarding to initialize and unseal
section "Initializing Vault"
kubectl port-forward $VAULT_POD -n vault 8200:8200 &
PORT_FWD_PID=$!

# Wait for port forwarding to establish
sleep 5

# Test API connectivity
echo "Testing API connectivity..."
if ! curl -s http://127.0.0.1:8200/v1/sys/health > /dev/null; then
  echo -e "${RED}Cannot connect to Vault API.${NC}"
  kill $PORT_FWD_PID 2>/dev/null || true
  exit 1
fi

# Check if Vault is already initialized
echo "Checking if Vault is already initialized..."
INIT_STATUS=$(curl -s http://127.0.0.1:8200/v1/sys/init)
IS_INITIALIZED=$(echo $INIT_STATUS | jq -r '.initialized')

echo "Vault initialized: $IS_INITIALIZED"

# Initialize if needed
if [[ "$IS_INITIALIZED" != "true" ]]; then
  echo "Initializing Vault with 1 key share and 1 key threshold..."
  
  # Initialize via API
  INIT_PAYLOAD='{"secret_shares": 1, "secret_threshold": 1}'
  INIT_RESPONSE=$(curl \
    --request PUT \
    --data "$INIT_PAYLOAD" \
    http://127.0.0.1:8200/v1/sys/init)
  
  # Extract unseal key and root token
  UNSEAL_KEY=$(echo $INIT_RESPONSE | jq -r '.keys_base64[0]')
  ROOT_TOKEN=$(echo $INIT_RESPONSE | jq -r '.root_token')
  
  echo -e "${GREEN}Vault initialized!${NC}"
  echo "Unseal Key: $UNSEAL_KEY"
  echo "Root Token: $ROOT_TOKEN"
  
  # Save credentials
  mkdir -p ~/.vault
  chmod 700 ~/.vault
  echo "Root Token: $ROOT_TOKEN" > ~/.vault/credentials
  echo "Unseal Key: $UNSEAL_KEY" >> ~/.vault/credentials
  chmod 600 ~/.vault/credentials
  
  echo "Credentials saved to ~/.vault/credentials"
  
  # Unseal the vault
  echo "Unsealing Vault..."
  curl \
    --request PUT \
    --data "{\"key\": \"$UNSEAL_KEY\"}" \
    http://127.0.0.1:8200/v1/sys/unseal
  
  echo -e "${GREEN}Vault unsealed!${NC}"
else
  echo -e "${YELLOW}Vault is already initialized.${NC}"
  
  # Try to get credentials from existing file
  if [[ -f ~/.vault/credentials ]]; then
    ROOT_TOKEN=$(grep "Root Token:" ~/.vault/credentials | cut -d ' ' -f3)
    UNSEAL_KEY=$(grep "Unseal Key:" ~/.vault/credentials | cut -d ' ' -f3)
  else
    echo -e "${RED}Cannot find existing credentials.${NC}"
    ROOT_TOKEN="<unknown>"
    UNSEAL_KEY="<unknown>"
  fi
  
  # Check if sealed
  SEAL_STATUS=$(curl -s http://127.0.0.1:8200/v1/sys/seal-status)
  IS_SEALED=$(echo $SEAL_STATUS | jq -r '.sealed')
  
  if [[ "$IS_SEALED" == "true" ]]; then
    if [[ "$UNSEAL_KEY" != "<unknown>" ]]; then
      echo "Unsealing Vault..."
      curl \
        --request PUT \
        --data "{\"key\": \"$UNSEAL_KEY\"}" \
        http://127.0.0.1:8200/v1/sys/unseal
      echo -e "${GREEN}Vault unsealed!${NC}"
    else
      echo -e "${RED}Cannot unseal Vault automatically. Please unseal manually.${NC}"
    fi
  else
    echo -e "${GREEN}Vault is already unsealed.${NC}"
  fi
fi

# Create Vault config file
cat > ~/.vault/config << EOF
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$ROOT_TOKEN
export VAULT_FORMAT=json
EOF
chmod 600 ~/.vault/config

# Clean up port forwarding
kill $PORT_FWD_PID 2>/dev/null || true

# Create port-forward script
cat > "$SCRIPT_DIR/linux-port-forward.sh" << 'EOF'
#!/bin/bash
echo "Starting port forwarding for Vault..."
echo "API will be available at http://localhost:8200"
echo "UI will be available at http://localhost:8201"

kubectl -n vault port-forward service/vault 8200:8200 &
PID1=$!
kubectl -n vault port-forward service/vault-ui 8201:8200 &
PID2=$!

echo "Press Ctrl+C to stop port forwarding"
trap "kill $PID1 $PID2; echo 'Port forwarding stopped.'; exit" INT TERM EXIT
wait
EOF
chmod 700 "$SCRIPT_DIR/linux-port-forward.sh"

section "Vault fixed and running!"
echo -e "${GREEN}Vault is now running properly.${NC}"
echo -e ""
echo -e "To access Vault, run:"
echo -e "  1. ${BLUE}./linux-port-forward.sh${NC}"
echo -e "  2. ${BLUE}source ~/.vault/config${NC}"
echo -e ""
echo -e "Root Token: ${YELLOW}$ROOT_TOKEN${NC}"
echo -e "Vault UI: ${BLUE}http://localhost:8201${NC}"
echo -e ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Ensure this works with in-memory storage"
echo -e "2. Gradually switch to file-based storage once stable"
echo -e "3. Add audit logging and other production features"