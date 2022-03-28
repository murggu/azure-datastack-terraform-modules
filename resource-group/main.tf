#Naming convention https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations

resource "azurerm_resource_group" "syn_rg" {
  name     = "rg-${var.prefix}-${var.postfix}"
  location = var.location
  tags     = var.tags
}