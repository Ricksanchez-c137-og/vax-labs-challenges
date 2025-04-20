provider "azure" {
  features {}
}

resource "azurerm_resource_group" "vaxlabs" {
  name     = "VaxLabsRG"
  location = "uaenorth"
}

resource "azurerm_virtual_network" "hub" {
  name                = "VaxLabs-Hub"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.vaxlabs.location
  resource_group_name = azurerm_resource_group.vaxlabs.name
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.vaxlabs.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_virtual_network" "challenge" {
  count               = 1024
  name                = "Challenge${count.index + 1}-VNet"
  address_space       = ["10.${count.index + 1}.0.0/16"]
  location            = azurerm_resource_group.vaxlabs.location
  resource_group_name = azurerm_resource_group.vaxlabs.name
}

resource "azurerm_subnet" "challenge_subnet" {
  count                = 1024
  name                 = "Challenge${count.index + 1}Subnet"
  resource_group_name  = azurerm_resource_group.vaxlabs.name
  virtual_network_name = azurerm_virtual_network.challenge[count.index].name
  address_prefixes     = ["10.${count.index + 1}.0.0/24"]
}

resource "azurerm_virtual_network_peering" "hub_to_challenge" {
  count                     = 1024  
  name                      = "Hub-To-Challenge${count.index + 1}"
  resource_group_name       = azurerm_resource_group.vaxlabs.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.challenge[count.index].id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "challenge_to_hub" {
  count                     = 1024 
  name                      = "Challenge${count.index + 1}-To-Hub"
  resource_group_name       = azurerm_resource_group.vaxlabs.name
  virtual_network_name      = azurerm_virtual_network.challenge[count.index].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
}

resource "azurerm_public_ip" "vpn_gateway" {
  name                = "VPN-Gateway-IP"
  location            = azurerm_resource_group.vaxlabs.location
  resource_group_name = azurerm_resource_group.vaxlabs.name
  allocation_method   = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "VaxLabs-VPN-Gateway"
  location            = azurerm_resource_group.vaxlabs.location
  resource_group_name = azurerm_resource_group.vaxlabs.name
  
  type     = "Vpn"
  vpn_type = "RouteBased"
  
  active_active = false
  enable_bgp    = false
  sku           = "Basic"
  
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  vpn_client_configuration {
    address_space = ["172.16.0.0/24"]
    
    root_certificate {
      name = "VaxLabsRootCert"
      public_cert_data = file("${path.module}/certs/root_cert.pem")
    }
  }
}

resource "azurerm_network_interface" "vpn_manager_nic" {
  name                = "vpn-manager-nic"
  location            = azurerm_resource_group.vaxlabs.location
  resource_group_name = azurerm_resource_group.vaxlabs.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.gateway.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vpn_manager" {
  name                = "vpn-manager-vm"
  resource_group_name = azurerm_resource_group.vaxlabs.name
  location            = azurerm_resource_group.vaxlabs.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.vpn_manager_nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")  # path to public key
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
}

output "vpn_gateway_public_ip" {
  value = azurerm_public_ip.vpn_gateway.ip_address
  description = "The public IP address of the VPN gateway"
}

output "challenge_network_ids" {
  value = [for net in azurerm_virtual_network.challenge : net.id]
  description = "IDs of the challenge virtual networks"
}