# CI/CD policy
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
}