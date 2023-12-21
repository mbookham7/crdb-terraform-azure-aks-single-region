#####################################
# Azure Infrastructure              #
#####################################

### Creation of VNET in three regions with a single subnet.

# Create a Azure Resource Group for all other resources.

resource "azurerm_resource_group" "mb-crdb-multi-region" {
  name     = "${var.prefix}-k8s-resources"
  location = var.location_1
}

# Create VNET in first region

resource "azurerm_virtual_network" "region_1" {
  name                = "${var.prefix}-${var.location_1}"
  location            = var.location_1
  resource_group_name = azurerm_resource_group.mb-crdb-multi-region.name
  address_space       = var.location_1_vnet_address_space
}

# Create subnet in first region

resource "azurerm_subnet" "internal-region_1" {
  name                 = "internal-${var.location_1}"
  virtual_network_name = azurerm_virtual_network.region_1.name
  resource_group_name  = azurerm_resource_group.mb-crdb-multi-region.name
  address_prefixes     = var.location_1_aks_subnet
}

### Identity
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks-cac-001"
  resource_group_name = azurerm_resource_group.mb-crdb-multi-region.name
  location            = var.location_1
}

resource "azurerm_role_assignment" "network_contributor_region_1" {
  scope                = azurerm_virtual_network.region_1.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

### Region 1 AKS Cluster Creation
resource "azurerm_kubernetes_cluster" "aks_region_1" {
  name                = "${var.prefix}-k8s-${var.location_1}"
  location            = var.location_1
  resource_group_name = azurerm_resource_group.mb-crdb-multi-region.name
  dns_prefix          = "${var.prefix}-k8s"

  default_node_pool {
    name           = var.aks_pool_name
    node_count     = var.aks_node_count
    vm_size        = var.aks_vm_size
    vnet_subnet_id = azurerm_subnet.internal-region_1.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin = "azure"
  }
}