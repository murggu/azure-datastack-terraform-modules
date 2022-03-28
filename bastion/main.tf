resource "azurerm_public_ip" "syn_pip" {
  name                = "pip-${var.prefix}-${var.postfix}"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "syn_bas" {
  name                = "bas-${var.prefix}-${var.postfix}"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.syn_pip.id
  }
}