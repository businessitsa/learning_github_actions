# infra/network.tf
resource "azurerm_virtual_network" "capstone" {
  name                = "vnet-capstone"
  resource_group_name = data.azurerm_resource_group.prod.name
  location            = data.azurerm_resource_group.prod.location
  address_space       = ["10.20.0.0/16"]

  tags = local.common_tags
}

# The application subnet. In this course version the container apps
# environment runs on Azure's shared network to stay within the free tier
# (custom VNet integration requires a dedicated /23 subnet and is left as a
# stretch exercise); the network is still real, managed infrastructure that
# the pipeline plans, applies and drift-checks like everything else.
resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = data.azurerm_resource_group.prod.name
  virtual_network_name = azurerm_virtual_network.capstone.name
  address_prefixes     = ["10.20.1.0/24"]
}
