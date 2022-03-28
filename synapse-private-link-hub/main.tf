locals {
  safe_prefix  = replace(var.prefix, "-", "")
  safe_postfix = replace(var.postfix, "-", "")
}

resource "azurerm_synapse_private_link_hub" "syn_synplh" {
  name                = "synplh${local.safe_prefix}${local.safe_postfix}"
  resource_group_name = var.rg_name
  location            = var.location
}

# DNS Zones

resource "azurerm_private_dns_zone" "synplh_zone_web" {
  name                = "privatelink.azuresynapse.net"
  resource_group_name = var.rg_name
}

# Private Endpoint configuration

resource "azurerm_private_endpoint" "synplh_pe_web" {
  name                = "pe-${azurerm_synapse_private_link_hub.syn_synplh.name}-web"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.prefix}-synplh-psc-web-${var.postfix}"
    private_connection_resource_id = azurerm_synapse_private_link_hub.syn_synplh.id
    subresource_names              = ["web"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-syn-web"
    private_dns_zone_ids = [azurerm_private_dns_zone.synplh_zone_web.id]
  }
}