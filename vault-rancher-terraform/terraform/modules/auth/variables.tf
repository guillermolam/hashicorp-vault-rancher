variable "oidc_scopes" {
  description = "List of OIDC scopes to request"
  type        = list(string)
  default     = ["openid", "profile", "email"]
}

variable "oidc_redirect_uri" {
  description = "Redirect URI for OIDC authentication"
  type        = string
}


variable "oidc_groups_claim" {
  description = "Claim to use for mapping OIDC groups"
  type        = string
  default     = "groups"
}

variable "oidc_discovery_url" {
  description = "OIDC discovery URL"
  type        = string
  default     = "https://guillermolam.auth0.com/.well-known/openid-configuration"
}

variable "oidc_client_id" {
  description = "OIDC client ID"
  type        = string
}

variable "oidc_client_secret" {
  description = "OIDC client secret"
  type        = string
}