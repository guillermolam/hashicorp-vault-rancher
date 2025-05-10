terraform {
  required_version = ">= 1.0.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0.0"
    }
  }
}

resource "vault_jwt_auth_backend" "oidc" {
  description        = "Auth0 OIDC authentication"
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = var.oidc_discovery_url
  oidc_client_id     = var.oidc_client_id
  oidc_client_secret = var.oidc_client_secret
  default_role       = "default"

  tune {
    listing_visibility = "unauth"
    default_lease_ttl  = "1h"
    max_lease_ttl      = "24h"
  }
}

resource "vault_jwt_auth_backend_role" "default" {
  backend        = vault_jwt_auth_backend.oidc.path
  role_name      = "default"
  token_policies = ["default"]

  bound_audiences = [var.oidc_client_id]
  user_claim      = "sub"
  groups_claim    = var.oidc_groups_claim
  role_type       = "oidc"
  allowed_redirect_uris = [
    var.oidc_redirect_uri
  ]
  oidc_scopes = var.oidc_scopes
}