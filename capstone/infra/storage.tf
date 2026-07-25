# infra/storage.tf
# Storage account names must be globally unique, lowercase alphanumeric,
# 3 to 24 characters. The random suffix keeps the name collision-free while
# the prefix keeps it recognisable.
resource "random_string" "storage_suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_storage_account" "data" {
  name                     = "stcapstone${random_string.storage_suffix.result}"
  resource_group_name      = data.azurerm_resource_group.prod.name
  location                 = data.azurerm_resource_group.prod.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Entra ID only, no shared keys: the same stance as the course's state
  # account, and it also keeps read-only plan refreshes free of key lookups.
  shared_access_key_enabled = false

  tags = local.common_tags
}
