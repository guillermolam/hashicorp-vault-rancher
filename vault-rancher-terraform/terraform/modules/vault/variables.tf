variable "name" {
  description = "Name to use for the Vault deployment"
  type        = string
  default     = "vault"
}

variable "ha_enabled" {
  description = "Enable high availability mode for Vault"
  type        = bool
  default     = true
}

variable "replica_count" {
  description = "Number of Vault server replicas"
  type        = number
  default     = 3
}