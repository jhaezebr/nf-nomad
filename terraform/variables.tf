variable "subscription_id" {
  description = "The Azure subscription ID to use."
}

variable "client_id" {
  description = "The Azure client ID to use."
}

variable "client_secret" {
  description = "The Azure client secret to use."
  sensitive = true
}

variable "tenant_id" {
  description = "The Azure tenant ID to use."
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "storage_account_name" {
  description = "The name of the storage account."
  type        = string
}

variable "location" {
  description = "The Azure region to deploy to."
  default     = "westeurope"
}

variable "allowlist_ip" {
  description = "IP to allow access for the security groups (set 0.0.0.0/0 for world)"
  default     = "0.0.0.0/0"
}

variable "server_instance_type" {
  description = "The Azure VM instance type to use for servers."
  default     = "Standard_B2ms"
}

variable "client_instance_type" {
  description = "The Azure VM type to use for clients."
  default     = "Standard_B8ms" # ? Standard_B16ms ?
}

variable "server_count" {
  description = "The number of servers to provision."
  default     = "1"
}

variable "client_count" {
  description = "The number of clients to provision."
  default     = "1"
}

variable "root_block_device_size" {
  description = "The volume size of the root block device."
  default     = 16
}

variable "nomad_binary" {
  description = "URL of a zip file containing a nomad executable to replace the Nomad binaries in the AMI with. Example: https://releases.hashicorp.com/nomad/0.10.0/nomad_0.10.0_linux_amd64.zip"
  default     = ""
}

variable "image_name" {
  description = "The Azure image to use for the server and client machines. Output from the Packer build process. This is the image NAME not the ID."
}

# Accessor ID for the Consul ACL token used by Nomad servers and clients
resource "random_uuid" "nomad_consul_token_id" {}

# Secret ID for the Consul ACL token used by Nomad servers and clients.
resource "random_uuid" "nomad_consul_token_secret" {}

#The password for the ubuntu account on the server and client machines.
resource "random_string" "admin_password" {
  length = 16
}