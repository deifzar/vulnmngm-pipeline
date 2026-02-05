terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatecptm8staging"
    container_name       = "tfstate-staging"
    key                  = "azure-staging.terraform.tfstate"
  }
}
