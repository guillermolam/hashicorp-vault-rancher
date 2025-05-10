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
