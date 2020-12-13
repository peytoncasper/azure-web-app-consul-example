data "azurerm_virtual_network" "hcs" {
  name                = var.hcs_virtual_network_name
  resource_group_name = var.hcs_resource_group
}

resource "azurerm_virtual_network" "gateway" {
  name                = "gateway-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.gateway.location
  resource_group_name = azurerm_resource_group.gateway.name
}

resource "azurerm_subnet" "gateway" {
  name                 = "consul-subnet"
  resource_group_name  = azurerm_resource_group.gateway.name
  virtual_network_name = azurerm_virtual_network.gateway.name
  address_prefixes       = ["10.0.2.0/24"]
}

resource "azurerm_virtual_network_peering" "gateway_to_hcs" {
  name                      = "gateway-to-hcs"
  resource_group_name       = azurerm_resource_group.gateway.name
  virtual_network_name      = azurerm_virtual_network.gateway.name
  remote_virtual_network_id = data.azurerm_virtual_network.hcs.id
}

resource "azurerm_virtual_network_peering" "hcs_to_gateway" {
  name                      = "hcs-to-gateway"
  resource_group_name       = var.hcs_resource_group
  virtual_network_name      = data.azurerm_virtual_network.hcs.name
  remote_virtual_network_id = azurerm_virtual_network.gateway.id
}