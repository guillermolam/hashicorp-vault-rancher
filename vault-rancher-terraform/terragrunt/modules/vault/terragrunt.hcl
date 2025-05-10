# terragrunt/modules/vault/terragrunt.hcl
include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../terraform/modules/vault"
}

inputs = {
  name = "vault"
  ha_enabled = var.vault_ha_enabled
  replica_count = var.vault_replica_count
}