# Admin policy
# This policy grants administrative access but with safeguards

# Allow administrative access to most paths
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Explicitly deny dangerous operations
path "sys/seal" {
  capabilities = ["deny"]
}

# Restrict access to audit logs (read-only)
path "sys/audit/*" {
  capabilities = ["read", "list"]
}

# Prevent deletion of audit devices
path "sys/audit/*" {
  capabilities = ["create", "update"]
  denied_parameters = ["type"]
}

# Prevent admins from changing their own policies
path "sys/policies/acl/admin" {
  capabilities = ["deny"]
}

# Audit trail for any token creations
path "auth/token/create*" {
  capabilities = ["create", "update", "sudo"]
  min_wrapping_ttl = "1m"
  max_wrapping_ttl = "90m"
}

# Restrict root token generation
path "sys/generate-root*" {
  capabilities = ["deny"]
}

# Restrict access to security barriers
path "sys/internal*" {
  capabilities = ["deny"]
}