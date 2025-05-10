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

# Clean up previous attempt
section "Cleaning up any existing deployment"
helm uninstall vault -n vault || true
kubectl delete namespace vault --ignore-not-found=true
echo "Waiting for namespace cleanup to complete..."
sleep 10

# Create namespace
kubectl create namespace vault

section "Getting Vault logs from previous attempts"
echo "Current failed pod logs might help debug the issues:"
kubectl logs vault-0 -n vault 2>/dev/null || echo "No previous logs found"

section "Installing Vault with debug configuration"
# Add Helm repo if needed
if ! helm repo list | grep -q "hashicorp"; then
  helm repo add hashicorp https://helm.releases.hashicorp.com
  helm repo update
fi

# Copy debug values
cp "$SCRIPT_DIR/debug-values.yaml" "$SCRIPT_DIR/vault-helm/values.yaml"

# Install Vault with debug values
helm install vault hashicorp/vault \
  --namespace vault \
  --values "$SCRIPT_DIR/vault-helm/values.yaml" \
  --debug

section "Verifying pod creation"
kubectl get pods -n vault -w & 
WATCH_PID=$!

# Give it some time to start
sleep 20
kill $WATCH_PID 2>/dev/null || true

# Check pod status
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$VAULT_POD" ]]; then
  section "Debugging pod details"
  echo "Pod details:"
  kubectl describe pod $VAULT_POD -n vault | grep -A 20 Events:
  
  echo "Pod logs:"
  kubectl logs $VAULT_POD -n vault || echo "No logs available"
  
  # Try port-forwarding to see if the service is listening
  echo "Testing port-forwarding (will timeout if service not running)..."
  timeout 5s kubectl port-forward $VAULT_POD -n vault 8200:8200 || echo "Port-forwarding timed out - service may not be listening"
  
  section "Pod status"
  kubectl get pod $VAULT_POD -n vault -o wide
else
  echo -e "${RED}No Vault pod found.${NC}"
fi

section "Debugging Summary"
echo -e "${YELLOW}If you see 'CrashLoopBackOff' or other errors:${NC}"
echo "1. Check the logs for specific error messages"
echo "2. Look for file permission or storage issues"
echo "3. Try examining ConfigMap contents:"
echo "   kubectl get configmap -n vault vault-config -o yaml"
echo ""
echo "Next step: Try in-memory storage only with minimal configuration"