terraform {
  
  backend "azurerm" {
    resource_group_name  = "nf-nomad-dev-rg"
    storage_account_name = "nfnomad"
    container_name       = "jhaezebrtest"
    key                  = "terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
  }
  required_version = ">= 0.12"
}

provider "azurerm" {
  features {}

  skip_provider_registration = true

  subscription_id = var.subscription_id
  client_id       = var.client_id
  tenant_id       = var.tenant_id
  client_secret   = var.client_secret
}

data "azurerm_resource_group" "nf-nomad" {
  name     = "nf-nomad-dev-rg"
}
