@echo off
echo Starting port forwarding for Vault...
echo API will be available at http://localhost:8200
echo UI will be available at http://localhost:8201

start /B kubectl -n vault port-forward service/vault 8200:8200
start /B kubectl -n vault port-forward service/vault-ui 8201:8200

echo Press Ctrl+C to stop port forwarding
pause
taskkill /FI "WINDOWTITLE eq kubectl*" /F
