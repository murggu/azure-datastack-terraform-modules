output "id" {
  value = azurerm_storage_account.syn_st.id
}

output "name" {
  value = azurerm_storage_account.syn_st.name
}

output "adls_id" {
  value = azurerm_storage_data_lake_gen2_filesystem.st_adls.id
}