# terragrunt/environments/prod-rancher/terragrunt.hcl
include {
  path = find_in_parent_folders()
}

# Variables specific to prod environment
inputs = {
  environment = "prod"
  kube_config_path = "~/.kube/config"
  kube_context = "rancher-desktop"  # This should match your Rancher context
  
  # Vault configuration
  vault_ha_enabled = true
  vault_replica_count = 3
  
  # Cert configuration
  create_certs = true
  cert_common_name = "vault.rancher.local"
  
  # Auth configuration
  auth_enabled = true
  oidc_discovery_url = "https://guillermolam.auth0.com/"
  # Sensitive values should be injected from environment variables or a vault
  oidc_client_id = get_env("OIDC_CLIENT_ID", "")
  oidc_client_secret = get_env("OIDC_CLIENT_SECRET", "")
  oidc_redirect_uri = "https://vault.guillermolam.com/oidc/callback"
  oidc_post_logout_redirect_uri = "https://vault.guillermolam.com/oidc/logout"
  oidc_scopes = ["openid", "profile", "email"]
  oidc_groups_claim = "groups"
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

dependency "auth" {
  config_path = "../../modules/auth"
  
  # Mock outputs for plan operations
  mock_outputs = {
    auth_path = "oidc"
  }
}