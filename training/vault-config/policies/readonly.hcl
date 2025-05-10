# Read-only policy
# This policy grants read-only access to secrets

# Allow listing and reading secrets
path "secret/data/*" {
  capabilities = ["read"]
}

path "secret/metadata/*" {
  capabilities = ["list"]
}

# Deny write access explicitly
path "secret/data/*" {
  capabilities = ["create", "update", "delete", "patch"]
  denied_parameters = ["*"]
}

# Deny access to all other paths by default
path "*" {
  capabilities = ["deny"]
}