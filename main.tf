# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used

# Create a resource group
resource "azurerm_resource_group" "example" {
  name     = "test-resources-tg"
  location = "West US 3"
}
# Generate random resource group name
resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

resource "random_id" "log_analytics_workspace_name_suffix" {
  byte_length = 8
}

resource "azurerm_log_analytics_workspace" "test" {
  location = var.log_analytics_workspace_location
  # The WorkSpace name has to be unique across the whole of azure;
  # not just the current subscription/tenant.
  name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = var.log_analytics_workspace_sku
}

resource "azurerm_log_analytics_solution" "test" {
  location              = azurerm_log_analytics_workspace.test.location
  resource_group_name   = azurerm_resource_group.rg.name
  solution_name         = "ContainerInsights"
  workspace_name        = azurerm_log_analytics_workspace.test.name
  workspace_resource_id = azurerm_log_analytics_workspace.test.id

  plan {
    product   = "OMSGallery/ContainerInsights"
    publisher = "Microsoft"
  }
}

resource "azurerm_kubernetes_cluster" "k8s" {
  location            = azurerm_resource_group.rg.location
  name                = var.cluster_name
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.dns_prefix
  tags = {
    Environment = "Development"
  }

  default_node_pool {
    name       = "agentpool"
    vm_size    = "Standard_D2_v2"
    node_count = var.agent_count
  }
  #linux_profile {
  #admin_username = "ubuntu"

  #ssh_key {
  #  key_data = file(var.ssh_public_key)
  #}
  #}
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
  identity {
    type = "SystemAssigned"
  }
  /*
  service_principal {
    client_id     = var.aks_service_principal_app_id
    client_secret = var.aks_service_principal_client_secret
  }
  */

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

}

output "id" {
  sensitive = false
  value     = azurerm_kubernetes_cluster.k8s.key_vault_secrets_provider[0].secret_identity
}


data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "myKeyVault" {
  name                = "ncmuthutestkv02"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id               = data.azurerm_client_config.current.tenant_id
    object_id               = azurerm_kubernetes_cluster.k8s.key_vault_secrets_provider[0].secret_identity.0.object_id
    key_permissions         = ["Get", ]
    secret_permissions      = ["Get", ]
    certificate_permissions = ["Get", ]
  }
}

# Create the namespace for certmanager and application
resource "helm_release" "namespaces" {
  name  = "namespaces"
  chart = "./helmcharts-infra/namespaces"
  values = [
    "${file("./helmcharts-infra/namespaces/values.yaml")}"
  ]
}
