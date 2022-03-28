# Azure Container Registry with Private Endpoint (Premium is required)

resource "azurerm_container_registry" "syn_cr" {
  name                = "cr${var.prefix}${var.postfix}"
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = "Premium"
  admin_enabled       = false

  network_rule_set {
    default_action  = "Deny"
    ip_rule         = []
    virtual_network = []
  }
}

# DNS Zones

resource "azurerm_private_dns_zone" "cr_zone" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.rg_name
}

# Linking of DNS zones to Virtual Network

resource "azurerm_private_dns_zone_virtual_network_link" "cr_zone_link" {
  name                  = "${var.prefix}${var.postfix}_link_acr"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.cr_zone.name
  virtual_network_id    = var.vnet_id
}

# Private Endpoint configuration

resource "azurerm_private_endpoint" "cr_pe" {
  name                = "pe-${azurerm_container_registry.syn_cr.name}-acr"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.prefix}-acr-psc-${var.postfix}"
    private_connection_resource_id = azurerm_container_registry.syn_cr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-acr"
    private_dns_zone_ids = [azurerm_private_dns_zone.cr_zone.id]
  }
}