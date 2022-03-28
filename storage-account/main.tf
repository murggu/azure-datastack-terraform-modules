# Storage Account with VNET binding and Private Endpoints for blob and dfs

data "azurerm_client_config" "current" {}

data "http" "ip" {
  url = "https://ifconfig.me"
}

resource "azurerm_storage_account" "syn_st" {
  name                     = "st${var.prefix}${var.postfix}"
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = var.hns_enabled
}

resource "azurerm_role_assignment" "st_role_admin_c" {
  scope                = azurerm_storage_account.syn_st.id
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "st_role_admin_sbdc" {
  scope                = azurerm_storage_account.syn_st.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "st_adls" {
  name               = "default"
  storage_account_id = azurerm_storage_account.syn_st.id

  depends_on = [
    azurerm_role_assignment.st_role_admin_sbdc
  ]
}

# Virtual Network & Firewall configuration

resource "azurerm_storage_account_network_rules" "firewall_rules" {
  resource_group_name  = var.rg_name
  storage_account_name = azurerm_storage_account.syn_st.name

  default_action             = "Deny"
  ip_rules                   = [data.http.ip.body]
  virtual_network_subnet_ids = var.firewall_virtual_network_subnet_ids
  bypass                     = var.firewall_bypass

  # Set network policies after Workspace has been created 
  # depends_on = [azurerm_synapse_workspace.syn_ws]
}

# DNS Zones

# resource "azurerm_private_dns_zone" "st_zone_blob" {
#   name                = "privatelink.blob.core.windows.net"
#   resource_group_name = var.rg_name
# }

# resource "azurerm_private_dns_zone" "st_zone_dfs" {
#   name                = "privatelink.dfs.core.windows.net"
#   resource_group_name = var.rg_name
# }

# Linking of DNS zones to Virtual Network

# resource "azurerm_private_dns_zone_virtual_network_link" "st_zone_blob_link" {
#   name                  = "${var.postfix}_link_blob"
#   resource_group_name   = var.rg_name
#   private_dns_zone_name = azurerm_private_dns_zone.st_zone_blob.name
#   virtual_network_id    = var.vnet_id
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "st_zone_dfs_link" {
#   name                  = "${var.postfix}_link_dfs"
#   resource_group_name   = var.rg_name
#   private_dns_zone_name = azurerm_private_dns_zone.st_zone_dfs.name
#   virtual_network_id    = var.vnet_id
# }

# Private Endpoint configuration

resource "azurerm_private_endpoint" "st_pe_blob" {
  name                = "pe-${azurerm_storage_account.syn_st.name}-blob"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.prefix}-st-psc-blob-${var.postfix}"
    private_connection_resource_id = azurerm_storage_account.syn_st.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-blob"
    private_dns_zone_ids = var.private_dns_zone_ids_blob
  }
}

resource "azurerm_private_endpoint" "st_pe_dfs" {
  name                = "pe-${azurerm_storage_account.syn_st.name}-dfs"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.prefix}-st-psc-dfs-${var.postfix}"
    private_connection_resource_id = azurerm_storage_account.syn_st.id
    subresource_names              = ["dfs"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-dfs"
    private_dns_zone_ids = var.private_dns_zone_ids_dfs
  }
}