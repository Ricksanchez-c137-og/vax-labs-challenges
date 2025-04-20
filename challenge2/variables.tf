# variables.tf - Define variables for the large AD deployment

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "vaxlabs-large-ad-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "vaxlabs-large-ad-vnet"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "dc_subnet_name" {
  description = "Name of the domain controller subnet"
  type        = string
  default     = "dc-subnet"
}

variable "dc_subnet_prefix" {
  description = "Address prefix for the domain controller subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "client_subnet_name" {
  description = "Name of the client subnet"
  type        = string
  default     = "client-subnet"
}

variable "client_subnet_prefix" {
  description = "Address prefix for the client subnet"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "file_server_subnet_name" {
  description = "Name of the file server subnet"
  type        = string
  default     = "file-server-subnet"
}

variable "file_server_subnet_prefix" {
  description = "Address prefix for the file server subnet"
  type        = list(string)
  default     = ["10.0.3.0/24"]
}

variable "domain_name" {
  description = "Active Directory domain name"
  type        = string
  default     = "vaxlabs.local"
}

variable "netbios_name" {
  description = "NetBIOS name for the Active Directory domain"
  type        = string
  default     = "VAXLABS"
}

variable "dc_count" {
  description = "Number of domain controllers to deploy"
  type        = number
  default     = 12
}

variable "client_count" {
  description = "Number of client machines to deploy"
  type        = number
  default     = 24
}

variable "file_server_count" {
  description = "Number of file servers to deploy"
  type        = number
  default     = 8
}

variable "dc_vm_size" {
  description = "VM size for domain controllers"
  type        = string
  default     = "Standard_B2ms"
}

variable "client_vm_size" {
  description = "VM size for client machines"
  type        = string
  default     = "Standard_B2s"
}

variable "file_server_vm_size" {
  description = "VM size for file servers"
  type        = string
  default     = "Standard_B2ms"
}

variable "admin_username" {
  description = "Admin username for the domain controllers and file servers"
  type        = string
  default     = "adminuser"
  sensitive   = true
}

variable "admin_password" {
  description = "Admin password for the domain controllers and file servers"
  type        = string
  sensitive   = true
}

variable "client_admin_username" {
  description = "Admin username for the client machines"
  type        = string
  default     = "clientadmin"
  sensitive   = true
}

variable "client_admin_password" {
  description = "Admin password for the client machines"
  type        = string
  sensitive   = true
}

variable "storage_account_name" {
  description = "Name of the storage account holding the scripts"
  type        = string
  sensitive   = true
}

variable "storage_container_name" {
  description = "Name of the storage container holding the scripts"
  type        = string
  default     = "scripts"
}

variable "storage_account_key" {
  description = "Access key for the storage account"
  type        = string
  sensitive   = true
}