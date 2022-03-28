# Key Vault with VNET binding and Private Endpoint

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "syn_kv" {
  name                = "kv-${var.prefix}-${var.postfix}"
  location            = var.location
  resource_group_name = var.rg_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  network_acls {
    default_action             = "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = []
    bypass                     = "None"
  }
}

# DNS Zones

resource "azurerm_private_dns_zone" "kv_zone" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.rg_name
}

# Linking of DNS zones to Virtual Network

resource "azurerm_private_dns_zone_virtual_network_link" "kv_zone_link" {
  name                  = "${var.postfix}_link_kv"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.kv_zone.name
  virtual_network_id    = var.vnet_id
}

# Private Endpoint configuration

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "pe-${azurerm_key_vault.syn_kv.name}-vault"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.prefix}-kv-psc-${var.postfix}"
    private_connection_resource_id = azurerm_key_vault.syn_kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-kv"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv_zone.id]
  }
}