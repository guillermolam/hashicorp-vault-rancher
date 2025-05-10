remote_state {
  backend = "local"
  config = {
    path = "${path_relative_to_include()}/terraform.tfstate"
  }
}

# Generate provider configurations
generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.17.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.8.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.13.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "kubernetes" {
  config_path = var.kube_config_path
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config_path
    config_context = var.kube_context
  }
}
EOF
}

# Common variables for all environments
inputs = {
  project_name = "vault-rancher"
}