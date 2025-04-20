# main.tf - Main deployment configuration for large AD environment

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "ad_rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "ad_vnet" {
  name                = var.vnet_name
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  address_space       = var.vnet_address_space
}

resource "azurerm_subnet" "dc_subnet" {
  name                 = var.dc_subnet_name
  resource_group_name  = azurerm_resource_group.ad_rg.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = var.dc_subnet_prefix
}

resource "azurerm_subnet" "client_subnet" {
  name                 = var.client_subnet_name
  resource_group_name  = azurerm_resource_group.ad_rg.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = var.client_subnet_prefix
}

resource "azurerm_subnet" "file_server_subnet" {
  name                 = var.file_server_subnet_name
  resource_group_name  = azurerm_resource_group.ad_rg.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = var.file_server_subnet_prefix
}

# Create network interfaces for domain controllers
resource "azurerm_network_interface" "dc_nic" {
  count               = var.dc_count
  name                = "dc${count.index + 1}-nic"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dc_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create network interfaces for client machines
resource "azurerm_network_interface" "client_nic" {
  count               = var.client_count
  name                = "client${count.index + 1}-nic"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.client_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create network interfaces for file servers
resource "azurerm_network_interface" "file_server_nic" {
  count               = var.file_server_count
  name                = "fs${count.index + 1}-nic"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.file_server_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create domain controller VMs
resource "azurerm_windows_virtual_machine" "dc_vm" {
  count               = var.dc_count
  name                = "DC${count.index + 1}"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  size                = var.dc_vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.dc_nic[count.index].id]
  
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
  
  computer_name = "DC${count.index + 1}"
}

# Create client VMs
resource "azurerm_windows_virtual_machine" "client_vm" {
  count               = var.client_count
  name                = "Client${count.index + 1}"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  size                = var.client_vm_size
  admin_username      = var.client_admin_username
  admin_password      = var.client_admin_password
  network_interface_ids = [azurerm_network_interface.client_nic[count.index].id]
  
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
  
  computer_name = "Client${count.index + 1}"
}

# Create file server VMs
resource "azurerm_windows_virtual_machine" "file_server_vm" {
  count               = var.file_server_count
  name                = "FS${count.index + 1}"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  size                = var.file_server_vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.file_server_nic[count.index].id]
  
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
  
  computer_name = "FS${count.index + 1}"
}

# Build script URL dynamically
locals {
  script_base_url = "https://${var.storage_account_name}.blob.core.windows.net/${var.storage_container_name}"
  domain_join_command = "powershell -ExecutionPolicy Unrestricted -Command \"Add-Computer -DomainName '${var.domain_name}' -Credential (New-Object System.Management.Automation.PSCredential('${var.domain_name}\\\\${var.admin_username}',(ConvertTo-SecureString '${var.admin_password}' -AsPlainText -Force))) -Restart -Force\""
}

# Setup primary domain controller
resource "azurerm_virtual_machine_extension" "dc1_extension" {
  name                 = "dc1-setup-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc_vm[0].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  
  settings = <<SETTINGS
{
  "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File setup_primary_dc.ps1 -DomainName ${var.domain_name} -NetbiosName ${var.netbios_name}"
}
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
{
  "fileUris": ["${local.script_base_url}/setup_primary_dc.ps1"],
  "storageAccountName": "${var.storage_account_name}",
  "storageAccountKey": "${var.storage_account_key}"
}
PROTECTED_SETTINGS

  depends_on = [azurerm_windows_virtual_machine.dc_vm[0]]
}

# Setup secondary domain controllers (DC2-DC12)
resource "azurerm_virtual_machine_extension" "additional_dc_extension" {
  count                = var.dc_count - 1
  name                 = "dc${count.index + 2}-setup-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc_vm[count.index + 1].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  
  settings = <<SETTINGS
{
  "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File setup_additional_dc.ps1 -DomainName ${var.domain_name} -AdminUser ${var.admin_username} -AdminPassword ${var.admin_password}"
}
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
{
  "fileUris": ["${local.script_base_url}/setup_additional_dc.ps1"],
  "storageAccountName": "${var.storage_account_name}",
  "storageAccountKey": "${var.storage_account_key}"
}
PROTECTED_SETTINGS

  depends_on = [azurerm_virtual_machine_extension.dc1_extension]
}

# Join file servers to domain
resource "azurerm_virtual_machine_extension" "file_server_extension" {
  count                = var.file_server_count
  name                 = "fs${count.index + 1}-setup-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.file_server_vm[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  
  settings = <<SETTINGS
{
  "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File setup_file_server.ps1 -DomainName ${var.domain_name} -AdminUser ${var.admin_username} -AdminPassword ${var.admin_password} -ServerNumber ${count.index + 1}"
}
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
{
  "fileUris": ["${local.script_base_url}/setup_file_server.ps1"],
  "storageAccountName": "${var.storage_account_name}",
  "storageAccountKey": "${var.storage_account_key}"
}
PROTECTED_SETTINGS

  depends_on = [azurerm_virtual_machine_extension.dc1_extension]
}

# Join client machines to domain
resource "azurerm_virtual_machine_extension" "client_extension" {
  count                = var.client_count
  name                 = "client${count.index + 1}-domainjoin-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.client_vm[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  
  settings = <<SETTINGS
{
  "commandToExecute": "${local.domain_join_command}"
}
SETTINGS

  depends_on = [azurerm_virtual_machine_extension.dc1_extension]
}