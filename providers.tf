terraform {
  required_version = ">=1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatestgacc02"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_kubernetes_cluster" "aks" {
  name                = azurerm_kubernetes_cluster.k8s.name
  resource_group_name = azurerm_kubernetes_cluster.k8s.resource_group_name
  depends_on = [
    azurerm_kubernetes_cluster.k8s,
  ]
}

provider "helm" {
  debug   = true
  kubernetes {
    host = data.azurerm_kubernetes_cluster.aks.kube_config[0].host

    client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}

