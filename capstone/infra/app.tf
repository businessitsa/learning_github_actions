# infra/app.tf
# A consumption-plan Container Apps environment. No Log Analytics workspace
# is attached, deliberately: application logs go nowhere in this teaching
# setup, which keeps it inside the free tier with zero standing cost. In
# production you would attach a workspace here.
resource "azurerm_container_app_environment" "capstone" {
  name                = "cae-capstone-prod"
  resource_group_name = data.azurerm_resource_group.prod.name
  location            = data.azurerm_resource_group.prod.location

  tags = local.common_tags
}

resource "azurerm_container_app" "hello" {
  name                         = "ca-capstone-prod"
  container_app_environment_id = azurerm_container_app_environment.capstone.id
  resource_group_name          = data.azurerm_resource_group.prod.name
  revision_mode                = "Single"

  template {
    # min_replicas = 0 is the cost story: the app scales to zero when idle
    # and consumes nothing from the monthly free grant while asleep.
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "hello"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = local.common_tags
}
