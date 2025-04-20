# variables.tf - Define variables for the AD deployment

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "vaxlabs-ad-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "uaenorth"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "vaxlabs-ad-vnet"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["192.168.0.0/16"]
}

variable "dc_subnet_name" {
  description = "Name of the domain controller subnet"
  type        = string
  default     = "dc-subnet"
}

variable "dc_subnet_prefix" {
  description = "Address prefix for the domain controller subnet"
  type        = list(string)
  default     = ["192.168.1.0/24"]
}

variable "client_subnet_name" {
  description = "Name of the client subnet"
  type        = string
  default     = "client-subnet"
}

variable "client_subnet_prefix" {
  description = "Address prefix for the client subnet"
  type        = list(string)
  default     = ["192.168.2.0/24"]
}

variable "domain_name" {
  description = "Active Directory domain name"
  type        = string
  default     = "vaxlabs.local"
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

variable "admin_username" {
  description = "Admin username for the domain controllers"
  type        = string
  default     = "adminuser"
  sensitive   = true
}

variable "admin_password" {
  description = "Admin password for the domain controllers"
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