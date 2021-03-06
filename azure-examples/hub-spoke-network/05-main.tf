locals {
  global-prefix = "z${random_string.prefix.result}"
}

# Create a Remote Backend
terraform {
  backend "azurerm" {
    # storage_account_name needs to be changed manually as variables are not supported.
    # Should be a format like "<random chars>terraform", eg: "ac1riyvpdterraform"
    storage_account_name = "<REPLACE-WITH-YOUR-STORAGE-ACCOUNT-NAME>"
    container_name       = "terraform-state"
    key                  = "terraform.tfstate"

    # access_key provided via ARM_ACCESS_KEY env var
  }
}

provider "azurerm" {
  # Pin version as per best practice
  version = "=1.39.0"
}

resource "random_string" "prefix" {
  length  = 4
  special = false
  number  = true
  lower   = false
  upper   = false
}
