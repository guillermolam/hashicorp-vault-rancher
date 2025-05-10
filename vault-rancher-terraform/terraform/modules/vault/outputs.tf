output "vault_service_name" {
  description = "Name of the Vault Kubernetes service"
  value       = "${var.name}-vault"
}