terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }

  # Remote state in Azure Storage.
  # Storage account / container / key are passed at "terraform init"
  # time using -backend-config (see environments/*.backend.hcl).
  backend "azurerm" {
    use_azuread_auth = true
  }
}

# Subscription is read from the ARM_SUBSCRIPTION_ID environment variable.
# Authentication comes from "az login" locally, or ARM_* variables in GitHub Actions.
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}