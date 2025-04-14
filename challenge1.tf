# This Terraform script sets up a basic Active Directory environment in Azure with two domain controllers and three client machines.
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "ad_rg" {
  name     = "vaxlabs-ad-rg"
  location = "uaenorth"
}

###############################
# 2. Virtual Network & Subnets
###############################

resource "azurerm_virtual_network" "ad_vnet" {
  name                = "vaxlabs-ad-vnet"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  address_space       = ["192.168.0.0/16"]
}

# Subnet for Domain Controllers
resource "azurerm_subnet" "dc_subnet" {
  name                 = "dc-subnet"
  resource_group_name  = azurerm_resource_group.ad_rg.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = ["192.168.1.0/24"]
}

# Subnet for Client Machines
resource "azurerm_subnet" "client_subnet" {
  name                 = "client-subnet"
  resource_group_name  = azurerm_resource_group.ad_rg.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = ["192.168.2.0/24"]
}

###############################
# 3. Network Interfaces (NICs)
###############################

# NICs for Domain Controllers
resource "azurerm_network_interface" "dc1_nic" {
  name                = "dc1-nic"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dc_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "dc2_nic" {
  name                = "dc2-nic"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dc_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# NICs for Client VMs
resource "azurerm_network_interface" "client1_nic" {
  name                = "client1-nic"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.client_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "client2_nic" {
  name                = "client2-nic"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.client_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "client3_nic" {
  name                = "client3-nic"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.client_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

###############################
# 4. Virtual Machines
###############################

# Domain Controller 1 (DC01) with vulnerable web app installation extension
resource "azurerm_windows_virtual_machine" "dc_vm1" {
  name                = "DC01"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  size                = "Standard_B2ms"
  admin_username      = "adminuser"
  admin_password      = "P@ssw0rd1234!" # Replace with secure method
  network_interface_ids = [azurerm_network_interface.dc1_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  computer_name = "DC01"
}

# Domain Controller 2 (DC02) - joins the domain
resource "azurerm_windows_virtual_machine" "dc_vm2" {
  name                = "DC02"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  size                = "Standard_B2ms"
  admin_username      = "adminuser"
  admin_password      = "P@ssw0rd1234!"
  network_interface_ids = [azurerm_network_interface.dc2_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  computer_name = "DC02"
}

# Client VM 1
resource "azurerm_windows_virtual_machine" "client_vm1" {
  name                = "Client1"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  size                = "Standard_B2s"
  admin_username      = "clientadmin"
  admin_password      = "P@ssw0rd1234!"
  network_interface_ids = [azurerm_network_interface.client1_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  computer_name = "Client1"
}

# Client VM 2
resource "azurerm_windows_virtual_machine" "client_vm2" {
  name                = "Client2"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  size                = "Standard_B2s"
  admin_username      = "clientadmin"
  admin_password      = "P@ssw0rd1234!"
  network_interface_ids = [azurerm_network_interface.client2_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  computer_name = "Client2"
}

# Client VM 3
resource "azurerm_windows_virtual_machine" "client_vm3" {
  name                = "Client3"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  size                = "Standard_B2s"
  admin_username      = "clientadmin"
  admin_password      = "P@ssw0rd1234!"
  network_interface_ids = [azurerm_network_interface.client3_nic.id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  computer_name = "Client3"
}

###############################
# 5. VM Extensions for AD Promotion & Vulnerable Web App Installation
###############################

# 5A. DC01: Promote to Primary Domain Controller and Install Vulnerable Web App
resource "azurerm_virtual_machine_extension" "dc1_extension" {
  name                 = "dc1-setup-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc_vm1.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  
  # The script installs AD DS (if needed) and also clones your vulnerable web app repository and configures IIS.
  settings = <<SETTINGS
{
  "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File dc_setup.ps1"
}
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
{
  "fileUris": ["https://<YOUR_STORAGE_ACCOUNT>.blob.core.windows.net/scripts/dc_setup.ps1"]
}
PROTECTED_SETTINGS
}

# 5B. DC02: Join Existing Domain as an Additional DC
resource "azurerm_virtual_machine_extension" "dc2_extension" {
  name                 = "dc2-domainjoin-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc_vm2.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  
  settings = <<SETTINGS
{
  "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File dc_join.ps1"
}
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
{
  "fileUris": ["https://<YOUR_STORAGE_ACCOUNT>.blob.core.windows.net/scripts/dc_join.ps1"]
}
PROTECTED_SETTINGS
}

# 5C. Client VMs: Domain Join
locals {
  domain_join_script = "powershell -ExecutionPolicy Unrestricted -Command \"Add-Computer -DomainName 'vaxlabs.local' -Credential (New-Object System.Management.Automation.PSCredential('vaxlabs\\\\adminuser',(ConvertTo-SecureString 'P@ssw0rd1234!' -AsPlainText -Force))) -Restart -Force\""
}

resource "azurerm_virtual_machine_extension" "client1_extension" {
  name                 = "client1-domainjoin-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.client_vm1.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  settings = <<SETTINGS
{
  "commandToExecute": "${local.domain_join_script}"
}
SETTINGS
}

resource "azurerm_virtual_machine_extension" "client2_extension" {
  name                 = "client2-domainjoin-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.client_vm2.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  settings = <<SETTINGS
{
  "commandToExecute": "${local.domain_join_script}"
}
SETTINGS
}

resource "azurerm_virtual_machine_extension" "client3_extension" {
  name                 = "client3-domainjoin-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.client_vm3.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  settings = <<SETTINGS
{
  "commandToExecute": "${local.domain_join_script}"
}
SETTINGS
}
