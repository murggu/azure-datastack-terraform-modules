variable "rg_name" {
  type        = string
  description = "Resource group name"
}

variable "location" {
  type        = string
  description = "Location of the resource group"
}

variable "prefix" {
  type        = string
  description = "Prefix for the module name"
}

variable "postfix" {
  type        = string
  description = "Postfix for the module name"
}

variable "jumphost_username" {
  type        = string
  description = "VM username"
}

variable "jumphost_password" {
  type        = string
  description = "VM password"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the virtual machine"
}