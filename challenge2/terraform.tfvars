# terraform.tfvars - Store your actual values here
# IMPORTANT: Do not commit this file to version control!

resource_group_name        = "vaxlabs-large-ad-rg"
location                   = "eastus"
vnet_name                  = "vaxlabs-large-ad-vnet"
vnet_address_space         = ["10.0.0.0/16"]

dc_subnet_name             = "dc-subnet"
dc_subnet_prefix           = ["10.0.1.0/24"]
client_subnet_name         = "client-subnet"
client_subnet_prefix       = ["10.0.2.0/24"]
file_server_subnet_name    = "file-server-subnet"
file_server_subnet_prefix  = ["10.0.3.0/24"]

domain_name                = "vaxlabs.local"
netbios_name               = "VAXLABS"

dc_count                   = 12
client_count               = 24
file_server_count          = 8

dc_vm_size                 = "Standard_B2ms"
client_vm_size             = "Standard_B2s"
file_server_vm_size        = "Standard_B2ms"

# Sensitive values - keep secure
admin_username             = "adminuser"
admin_password             = "P@ssw0rd1234!"
client_admin_username      = "clientadmin"
client_admin_password      = "P@ssw0rd1234!"
storage_account_name       = "vaxlabsscripts"
storage_container_name     = "scripts"
storage_account_key        = "your-storage-account-key"