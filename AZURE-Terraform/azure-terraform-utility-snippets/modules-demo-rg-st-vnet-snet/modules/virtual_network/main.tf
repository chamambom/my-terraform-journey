#Location: .\Modules\virtual_network
#Azure virtual network module main.tf file
resource "azurerm_virtual_network" "vnet" {
  name                = var.name
  resource_group_name = var.resource_group_name  
  location            = var.location
  address_space       = var.address_space
}


