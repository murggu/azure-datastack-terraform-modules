# Azure Synapse Workspace 

data "azurerm_client_config" "current" {}

data "http" "ip" {
  url = "https://ifconfig.me"
}

resource "azurerm_synapse_workspace" "syn_ws" {
  name                                 = "syn-${var.prefix}-${var.postfix}"
  resource_group_name                  = var.rg_name
  location                             = var.location
  storage_data_lake_gen2_filesystem_id = var.adls_id

  sql_administrator_login          = var.synadmin_username
  sql_administrator_login_password = var.synadmin_password

  managed_virtual_network_enabled = true
  managed_resource_group_name     = "${var.rg_name}-syn-managed"

  aad_admin {
    login     = var.aad_login.name
    object_id = var.aad_login.object_id
    tenant_id = var.aad_login.tenant_id
  }
}

# Virtual Network & Firewall configuration

resource "azurerm_synapse_firewall_rule" "allow_my_ip" {
  name                 = "AllowMyPublicIp"
  synapse_workspace_id = azurerm_synapse_workspace.syn_ws.id
  start_ip_address     = data.http.ip.body
  end_ip_address       = data.http.ip.body
}

resource "azurerm_role_assignment" "syn_ws_sa_role_si_sbdc" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.syn_ws.identity[0]["principal_id"]
}

resource "azurerm_role_assignment" "syn_ws_sa_role_si_c" {
  scope                = var.storage_account_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_synapse_workspace.syn_ws.identity[0]["principal_id"]
}

# DNS Zones

resource "azurerm_private_dns_zone" "syn_zone_dev" {
  name                = "privatelink.dev.azuresynapse.net"
  resource_group_name = var.rg_name
}

resource "azurerm_private_dns_zone" "syn_zone_sql" {
  name                = "privatelink.sql.azuresynapse.net"
  resource_group_name = var.rg_name
}

# Linking of DNS zones to Virtual Network

resource "azurerm_private_dns_zone_virtual_network_link" "syn_zone_dev_link" {
  name                  = "${var.postfix}_link_dev"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.syn_zone_dev.name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "sa_zone_sql_link" {
  name                  = "${var.postfix}_link_sql"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.syn_zone_sql.name
  virtual_network_id    = var.vnet_id
}

# Private Endpoint configuration

resource "azurerm_private_endpoint" "syn_ws_pe_dev" {
  name                = "pe-${azurerm_synapse_workspace.syn_ws.name}-dev"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.prefix}-syn-ws-psc-dev-${var.postfix}"
    private_connection_resource_id = azurerm_synapse_workspace.syn_ws.id
    subresource_names              = ["dev"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-dev"
    private_dns_zone_ids = [azurerm_private_dns_zone.syn_zone_dev.id]
  }
}

resource "azurerm_private_endpoint" "syn_ws_pe_sql" {
  name                = "pe-${azurerm_synapse_workspace.syn_ws.name}-sql"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.prefix}-syn-ws-pe-sql-${var.postfix}"
    private_connection_resource_id = azurerm_synapse_workspace.syn_ws.id
    subresource_names              = ["sql"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-sql"
    private_dns_zone_ids = [azurerm_private_dns_zone.syn_zone_sql.id]
  }
}

resource "azurerm_private_endpoint" "syn_ws_pe_sqlondemand" {
  name                = "pe-${azurerm_synapse_workspace.syn_ws.name}-sqlondemand"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.prefix}-syn-ws-pe-sqlondemand-${var.postfix}"
    private_connection_resource_id = azurerm_synapse_workspace.syn_ws.id
    subresource_names              = ["sqlondemand"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-sqlondemand"
    private_dns_zone_ids = [azurerm_private_dns_zone.syn_zone_sql.id]
  }
}

# Managed Private Endpoint configuration

resource "azurerm_synapse_managed_private_endpoint" "syn_ws_pe_managed_sa_dfs" {
  name                 = "${var.prefix}-ws-sa-managed-pe-dfs-${var.postfix}"
  synapse_workspace_id = azurerm_synapse_workspace.syn_ws.id
  target_resource_id   = var.storage_account_id
  subresource_name     = "dfs"

  depends_on = [
    azurerm_synapse_firewall_rule.allow_my_ip,
    azurerm_private_endpoint.syn_ws_pe_sqlondemand,
    azurerm_private_endpoint.syn_ws_pe_sql,
    azurerm_private_endpoint.syn_ws_pe_dev
  ]
}

resource "azurerm_synapse_managed_private_endpoint" "syn_ws_pe_managed_kv" {
  name                 = "${var.prefix}-ws-kv-managed-pe-${var.postfix}"
  synapse_workspace_id = azurerm_synapse_workspace.syn_ws.id
  target_resource_id   = var.key_vault_id
  subresource_name     = "vault"

  depends_on = [
    azurerm_synapse_firewall_rule.allow_my_ip,
    azurerm_private_endpoint.syn_ws_pe_sqlondemand,
    azurerm_private_endpoint.syn_ws_pe_sql,
    azurerm_private_endpoint.syn_ws_pe_dev
  ]
}


# Once the Synapse Managed Endpoint request has been created, approve it 

resource "null_resource" "azurecli_syn_approve_pe_adf_01" {

  provisioner "local-exec" {

    interpreter = ["/bin/bash", "-c"]
    working_dir = path.module

    # https://github.com/Azure/azure-cli/issues/13573
    command = <<EOT
          synId=$(az storage account show -n $storageAccountName --query "privateEndpointConnections[2].id" -o tsv | tr -d '\r\n')
          echo "APPROVING |"$synId"|"
          az storage account private-endpoint-connection approve --id $synId --description "Approved by Terraform"
      EOT

    environment = {
      storageAccountName = "${var.storage_account_name}"
      resourceGroup      = "${var.rg_name}"
    }
  }

  depends_on = [
    time_sleep.wait_50_seconds
  ]
}

resource "null_resource" "azurecli_syn_approve_pe_kv_01" {

  provisioner "local-exec" {

    interpreter = ["/bin/bash", "-c"]
    working_dir = path.module

    # https://github.com/Azure/azure-cli/issues/13573
    command = <<EOT
          synId=$(az keyvault show -n $keyVaultName --query "properties.privateEndpointConnections[1].id" -o tsv | tr -d '\r\n')
          echo "APPROVING |"$synId"|"
          az keyvault private-endpoint-connection approve --id $synId --description "Approved by Terraform"
      EOT

    environment = {
      keyVaultName  = "${var.key_vault_name}"
      resourceGroup = "${var.rg_name}"
    }
  }

  depends_on = [
    time_sleep.wait_50_seconds
  ]
}

resource "null_resource" "azurecli_syn_add_exception_01" {

  provisioner "local-exec" {

    # https://docs.microsoft.com/en-us/azure/synapse-analytics/sql/develop-storage-files-storage-access-control?tabs=user-identity
    command = "az storage account network-rule add --resource-group $resourceGroup --account-name $storageAccountName --tenant-id $tenantId --resource-id $synWorkspaceId"

    environment = {
      storageAccountName = "${var.storage_account_name}"
      resourceGroup      = "${var.rg_name}"
      tenantId           = "${var.aad_login.tenant_id}"
      synWorkspaceId     = "${azurerm_synapse_workspace.syn_ws.id}"
    }
  }

  depends_on = [
    time_sleep.wait_50_seconds
  ]
}

resource "time_sleep" "wait_50_seconds" {

  depends_on = [
    azurerm_synapse_managed_private_endpoint.syn_ws_pe_managed_sa_dfs,
    azurerm_synapse_managed_private_endpoint.syn_ws_pe_managed_kv
  ]

  create_duration = "50s"
}