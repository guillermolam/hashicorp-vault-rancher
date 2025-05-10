include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../terraform/modules/certificates"
}

inputs = {
  namespace = "vault"
  ca_common_name = "${var.environment}-vault-ca"
  cert_common_name = var.cert_common_name
}