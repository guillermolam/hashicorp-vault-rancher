#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Checking Vault Pod and Container Names ===${NC}"

# Get the pod name
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$VAULT_POD" ]]; then
  echo -e "${RED}No Vault pod found in the vault namespace.${NC}"
  exit 1
fi

echo -e "${GREEN}Found Vault pod: $VAULT_POD${NC}"

# Check container names
echo -e "${YELLOW}Getting container details...${NC}"
kubectl get pod $VAULT_POD -n vault -o jsonpath='{.spec.containers[*].name}' | tr ' ' '\n'

echo -e "\n${YELLOW}Container Statuses:${NC}"
kubectl get pod $VAULT_POD -n vault -o jsonpath='{range .status.containerStatuses[*]}{.name}{": ready="}{.ready}{", state="}{.state}{"\n"}{end}'

echo -e "\n${YELLOW}Detailed pod description:${NC}"
kubectl describe pod $VAULT_POD -n vault

echo -e "\n${BLUE}=== Try to execute a command in container ===${NC}"
echo -e "${YELLOW}Attempt with default container name 'vault':${NC}"
kubectl exec -it $VAULT_POD -n vault -- ls / 2>/dev/null || echo -e "${RED}Command failed with default container${NC}"

# Try to get the first container name from the pod
FIRST_CONTAINER=$(kubectl get pod $VAULT_POD -n vault -o jsonpath='{.spec.containers[0].name}')
if [[ -n "$FIRST_CONTAINER" && "$FIRST_CONTAINER" != "vault" ]]; then
  echo -e "\n${YELLOW}Attempting with first container name '$FIRST_CONTAINER':${NC}"
  kubectl exec -it $VAULT_POD -c $FIRST_CONTAINER -n vault -- ls / 2>/dev/null || \
    echo -e "${RED}Command failed with container $FIRST_CONTAINER${NC}"
fi

echo -e "\n${BLUE}=== Initializing Vault via API instead of CLI ===${NC}"
echo "Setting up port-forwarding..."
kubectl port-forward $VAULT_POD -n vault 8200:8200 &
PORT_FWD_PID=$!

# Give port forwarding a moment to establish
sleep 5

# Try to initialize using API
echo "Checking status via API..."
curl -s http://127.0.0.1:8200/v1/sys/init || echo "API connection failed"

# Check if initialized
INIT_STATUS=$(curl -s http://127.0.0.1:8200/v1/sys/init || echo '{"initialized": false}')
IS_INITIALIZED=$(echo $INIT_STATUS | jq -r '.initialized')

echo "Vault initialized via API check: $IS_INITIALIZED"

if [[ "$IS_INITIALIZED" != "true" ]]; then
  echo "Attempting to initialize via API..."
  INIT_PAYLOAD='{"secret_shares": 1, "secret_threshold": 1}'
  curl \
    --request PUT \
    --data "$INIT_PAYLOAD" \
    http://127.0.0.1:8200/v1/sys/init || echo "API init failed"
fi

# Clean up port forwarding
kill $PORT_FWD_PID

echo -e "\n${BLUE}=== Diagnostics complete ===${NC}"