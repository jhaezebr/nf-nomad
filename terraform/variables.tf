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
