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

section "Cleaning up any existing deployment"
kubectl delete namespace vault --ignore-not-found=true
echo "Waiting for namespace cleanup to complete..."
sleep 5

section "Creating namespace"
kubectl create namespace vault

section "Installing Vault in development mode"
# Add Helm repo if needed
if ! helm repo list | grep -q "hashicorp"; then
  helm repo add hashicorp https://helm.releases.hashicorp.com
  helm repo update
fi

# Install Vault with development mode enabled
helm install vault hashicorp/vault \
  --namespace vault \
  --values "$SCRIPT_DIR/vault-helm/values.yaml"

section "Waiting for Vault pod to be ready"
# More minimal approach to wait for pod
ATTEMPTS=0
MAX_ATTEMPTS=30
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  echo "Checking pod status... (Attempt $((ATTEMPTS+1))/$MAX_ATTEMPTS)"
  PHASE=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault-0 -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
  READY=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault-0 -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
  
  if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
    VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
    echo -e "${GREEN}Vault pod $VAULT_POD is running and ready!${NC}"
    break
  fi
  
  # Show more diagnostics
  if [[ "$PHASE" != "Running" ]]; then
    echo "Pod phase: $PHASE"
    kubectl describe pods -n vault -l app.kubernetes.io/name=vault | grep -A 5 "Events:"
  elif [[ "$READY" != "true" ]]; then
    echo "Pod is running but not ready yet"
  fi
  
  ATTEMPTS=$((ATTEMPTS+1))
  sleep 10
done

if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
  section "Deployment diagnostics"
  echo "Pod did not become ready in the allowed time. Current status:"
  kubectl get pods -n vault -o wide
  echo -e "\nPod details:"
  kubectl describe pods -n vault -l app.kubernetes.io/name=vault
  echo -e "\nPod logs:"
  VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -n "$VAULT_POD" ]]; then
    kubectl logs $VAULT_POD -n vault
  fi
  echo -e "${RED}Vault installation failed. See above for details.${NC}"
  exit 1
fi

section "Setting up access"
# In development mode, the root token is 'root'
ROOT_TOKEN="root"

# Save configuration for CLI
mkdir -p ~/.vault
chmod 700 ~/.vault

cat > ~/.vault/config << EOF
export VAULT_ADDR=http://localhost:8200 
export VAULT_TOKEN=$ROOT_TOKEN
export VAULT_FORMAT=json
EOF
chmod 600 ~/.vault/config

# Store in Kubernetes secret for Windows access
kubectl -n vault create secret generic vault-token \
  --from-literal=root_token=$ROOT_TOKEN

section "Creating port-forward scripts"
# Linux port-forward script
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

# Windows port-forward script
cat > "$SCRIPT_DIR/vault-port-forward.bat" << 'EOF'
@echo off
echo Starting port forwarding for Vault...
echo API will be available at http://localhost:8200
echo UI will be available at http://localhost:8201

start /B kubectl -n vault port-forward service/vault 8200:8200
start /B kubectl -n vault port-forward service/vault-ui 8201:8200

echo Press Ctrl+C to stop port forwarding
pause
taskkill /FI "WINDOWTITLE eq kubectl*" /F
EOF

section "Installation complete!"
echo -e "${GREEN}Vault development server is now running.${NC}"
echo -e "${YELLOW}NOTE: Development mode does not persist data across restarts.${NC}"
echo -e ""
echo -e "To access Vault, run:"
echo -e "  1. ${BLUE}./linux-port-forward.sh${NC}"
echo -e "  2. ${BLUE}source ~/.vault/config${NC}"
echo -e ""
echo -e "Root Token: ${YELLOW}$ROOT_TOKEN${NC}"
echo -e "Vault UI: ${BLUE}http://localhost:8201${NC}"