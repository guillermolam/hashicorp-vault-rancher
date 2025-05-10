terraform {
  required_version = ">= 1.0.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10.0"
    }
  }
  # This block prevents terraform from creating the backend during init
  # which is necessary for the test to run
  backend "local" {}
}

# This is a minimal placeholder that will be expanded as we develop
# the module following TDD principles
resource "helm_release" "vault" {
  name       = var.name
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"

  set {
    name  = "server.ha.enabled"
    value = var.ha_enabled
  }

  set {
    name  = "server.ha.replicas"
    value = var.replica_count
  }
}