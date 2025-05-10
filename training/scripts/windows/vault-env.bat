@echo off
echo Setting Vault environment variables...

REM Get the root token from Kubernetes secret
for /F "tokens=*" %%A in ('kubectl -n vault get secret vault-token -o jsonpath^="{.data.root_token}" ^| base64 --decode') do set VAULT_TOKEN=%%A

REM Set the Vault address
set VAULT_ADDR=http://localhost:8200

echo VAULT_ADDR=%VAULT_ADDR%
echo VAULT_TOKEN set successfully

REM Create the credentials file in the user's profile directory
if not exist "%USERPROFILE%\.vault" mkdir "%USERPROFILE%\.vault"
echo Root Token: %VAULT_TOKEN% > "%USERPROFILE%\.vault\credentials.txt"
echo Vault address: %VAULT_ADDR% >> "%USERPROFILE%\.vault\credentials.txt"

echo Credentials saved to %USERPROFILE%\.vault\credentials.txt