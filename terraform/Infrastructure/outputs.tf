output "nomad_address" {
  value = "http://${azurerm_linux_virtual_machine.server[0].private_ip_address}:4646"
}

output "consul_bootstrap_token_secret" {
  value = random_uuid.nomad_consul_token_secret.result
}

output "consul_address" {
  value = "http://${azurerm_linux_virtual_machine.server[0].private_ip_address}:8500"
}

output "job_filesystem_name" {
  value = azurerm_storage_share.hashistack_job_filesystem.name
}
