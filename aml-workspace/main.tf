# Azure Machine Learning Workspace with Private Endpoints

data "http" "ip" {
  url = "https://ifconfig.me"
}

resource "azurerm_machine_learning_workspace" "syn_mlw" {
  name                    = "mlw-${var.prefix}-${var.postfix}"
  location                = var.location
  resource_group_name     = var.rg_name
  application_insights_id = var.application_insights_id
  key_vault_id            = var.key_vault_id
  storage_account_id      = var.storage_account_id
  container_registry_id   = var.container_registry_id

  identity {
    type = "SystemAssigned"
  }
}

# DNS Zones

resource "azurerm_private_dns_zone" "mlw_zone_api" {
  name                = "privatelink.api.azureml.ms"
  resource_group_name = var.rg_name
}

resource "azurerm_private_dns_zone" "mlw_zone_notebooks" {
  name                = "privatelink.notebooks.azure.net"
  resource_group_name = var.rg_name
}

# Linking of DNS zones to Virtual Network

resource "azurerm_private_dns_zone_virtual_network_link" "mlw_zone_api_link" {
  name                  = "${var.postfix}_link_api"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.mlw_zone_api.name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "mlw_zone_notebooks_link" {
  name                  = "${var.postfix}_link_notebooks"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.mlw_zone_notebooks.name
  virtual_network_id    = var.vnet_id
}

# Private Endpoint configuration

resource "azurerm_private_endpoint" "mlw_pe" {
  name                = "pe-${azurerm_machine_learning_workspace.syn_mlw.name}-amlw"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.prefix}-aml-ws-psc-${var.postfix}"
    private_connection_resource_id = azurerm_machine_learning_workspace.syn_mlw.id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-ws"
    private_dns_zone_ids = [azurerm_private_dns_zone.mlw_zone_api.id, azurerm_private_dns_zone.mlw_zone_notebooks.id]
  }

  # Add Private Link after we configured the workspace and attached AKS
  # depends_on = [null_resource.compute_resouces, azurerm_kubernetes_cluster.aml_aks]

}