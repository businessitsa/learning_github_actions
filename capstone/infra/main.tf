# infra/main.tf
terraform {
  required_version = ">= 1.12.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tofu-state"
    storage_account_name = "REPLACE-WITH-YOUR-STATE-ACCOUNT-NAME"
    container_name       = "tfstate"
    key                  = "prod.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}

# The resource group is created once by scripts/setup-azure.sh, because the
# pipeline's RBAC is scoped to it and a scope must exist before a role can be
# assigned on it. The pipeline manages everything inside it.
data "azurerm_resource_group" "prod" {
  name = "rg-capstone-prod"
}

locals {
  common_tags = {
    project    = "capstone"
    managed_by = "opentofu"
    repository = var.repository
  }
}
