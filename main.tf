provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "gateway" {
  name     = var.gateway_resource_group_name
  location = "East US"
}

resource "azurerm_public_ip" "gateway" {
  name                    = "gateway-pip"
  location                = azurerm_resource_group.gateway.location
  resource_group_name     = azurerm_resource_group.gateway.name
  allocation_method       = "Dynamic"
}


data "azurerm_public_ip" "gateway" {
  name                = "gateway-pip"
  resource_group_name = azurerm_resource_group.gateway.name
  depends_on = [azurerm_public_ip.gateway]
}

resource "azurerm_network_interface" "gateway" {
  name                = "gateway-nic"
  location            = azurerm_resource_group.gateway.location
  resource_group_name = azurerm_resource_group.gateway.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.gateway.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.gateway.id
  }
}

resource "azurerm_linux_virtual_machine" "gateway" {
  name                = "gateway"
  resource_group_name = azurerm_resource_group.gateway.name
  location            = azurerm_resource_group.gateway.location
  size                = "Standard_B1MS"

  admin_username = "consul"

  network_interface_ids = [
    azurerm_network_interface.gateway.id,
  ]

  custom_data = base64encode(templatefile(
      "${path.module}/templates/gateway.tpl",
      {
        consul_version = "1.9.0",
        azure_web_app_domain = var.web_app_domain,
        hcs_bootstrap_token = var.hcs_bootstrap_token
      }
    )
  )

  admin_ssh_key {
    username   = "consul"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "file" {
    source      = var.consul_ca_path
    destination = "/tmp/ca.pem"

    connection {
      type     = "ssh"
      user     = "consul"
      private_key = file("~/.ssh/id_rsa")
      host     = self.public_ip_address
    }
  }

  provisioner "file" {
    source      = var.consul_config_path
    destination = "/tmp/consul.json"

    connection {
      type     = "ssh"
      user     = "consul"
      private_key = file("~/.ssh/id_rsa")
      host     = self.public_ip_address
    }
  }

  depends_on = [data.azurerm_public_ip.gateway]
}