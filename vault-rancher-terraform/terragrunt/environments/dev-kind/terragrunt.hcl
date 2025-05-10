# terragrunt/environments/dev-kind/terragrunt.hcl
include {
  path = find_in_parent_folders()
}

# Variables specific to dev environment
inputs = {
  environment = "dev"
  kube_config_path = "~/.kube/config"
  kube_context = "kind-vault-dev"  # This should match your Kind cluster name
  
  # Vault configuration
  vault_ha_enabled = false
  vault_replica_count = 1
  
  # Cert configuration
  create_certs = true
  cert_common_name = "vault.kind.local"
  
  # Auth configuration
  auth_enabled = false  # For dev, we'll start without Auth0 integration
}

# Define dependencies between modules
dependency "vault" {
  config_path = "../../modules/vault"
  
  # Mock outputs for plan operations
  mock_outputs = {
    vault_service_name = "vault"
  }
}

dependency "certificates" {
  config_path = "../../modules/certificates"
  
  # Mock outputs for plan operations
  mock_outputs = {
    cert_secret_name = "vault-tls"
  }
}