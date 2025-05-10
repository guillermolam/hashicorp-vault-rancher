# terragrunt/modules/auth/terragrunt.hcl
include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../terraform/modules/auth"
}

inputs = {
  vault_name = "vault"
  namespace = "vault"
  oidc_discovery_url = var.oidc_discovery_url
  oidc_client_id = var.oidc_client_id
  oidc_client_secret = var.oidc_client_secret
  oidc_redirect_uri = var.oidc_redirect_uri
  oidc_post_logout_redirect_uri = var.oidc_post_logout_redirect_uri
  oidc_scopes = var.oidc_scopes
  oidc_groups_claim = var.oidc_groups_claim
}