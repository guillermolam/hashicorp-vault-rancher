# Application policy
# Follows principle of least privilege
# Only grants access to application-specific paths

# Allow the application to manage its own secrets
path "secret/data/{{identity.entity.name}}/*" {
  capabilities = ["create", "update", "read", "delete"]
}

path "secret/metadata/{{identity.entity.name}}/*" {
  capabilities = ["list"]
}

# Allow read-only access to shared configuration
path "secret/data/shared/*" {
  capabilities = ["read"]
}

path "secret/metadata/shared/*" {
  capabilities = ["list"]
}

# Allow the application to use transit encryption for its data
path "transit/encrypt/{{identity.entity.name}}" {
  capabilities = ["update"]
}

path "transit/decrypt/{{identity.entity.name}}" {
  capabilities = ["update"]
}

# Deny access to all other paths by default
path "*" {
  capabilities = ["deny"]
}

# Limit token creation and renewal
path "auth/token/renew" {
  capabilities = ["update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}