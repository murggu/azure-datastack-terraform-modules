# Virtual Network definition

resource "azurerm_virtual_network" "syn_vnet" {
  name                = "vnet-${var.prefix}-${var.postfix}"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.rg_name

  tags = var.tags
}