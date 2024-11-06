# resource "azurerm_public_ip" "hashistack-server-public-ip" {
#   count                        = "${var.server_count}"
#   name                         = "hashistack-server-ip-${count.index}"
#   location                     = "${var.location}"
#   resource_group_name          = "${data.azurerm_resource_group.nf-nomad.name}"
#   allocation_method            = "Static"
# }

resource "azurerm_network_interface" "hashistack-server-ni" {
  count                     = "${var.server_count}"
  name                      = "hashistack-server-ni-${count.index}"
  location                  = "${var.location}"
  resource_group_name       = "${data.azurerm_resource_group.nf-nomad.name}"

  ip_configuration {
    name                          = "hashistack-ipc"
    subnet_id                     = "${azurerm_subnet.hashistack-sn.id}"
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = "${element(azurerm_public_ip.hashistack-server-public-ip.*.id, count.index)}"
  }

  tags                            = {"ConsulAutoJoin" = "auto-join"}
}


resource "azurerm_linux_virtual_machine" "server" {
  name                  = "hashistack-server-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${data.azurerm_resource_group.nf-nomad.name}"
  network_interface_ids = ["${element(azurerm_network_interface.hashistack-server-ni.*.id, count.index)}"]
  size                  = "${var.server_instance_type}"
  count                 = "${var.server_count}"

  boot_diagnostics {
    storage_account_uri = "https://${data.azurerm_storage_account.hashistack_job.name}.blob.core.windows.net/"
  }

  source_image_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Compute/images/${var.image_name}"

  os_disk {
    name              = "hashistack-server-osdisk-${count.index}"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  computer_name  = "hashistack-server-${count.index}"
  admin_username = "ubuntu"
  admin_password = random_string.server_admin_password.result
  custom_data    = "${base64encode(templatefile("${path.module}/data-scripts/user-data-server.sh", {
      region                    = var.location
      cloud_env                 = "azure"
      server_count              = "${var.server_count}"
      retry_join                = join(" ", [
        "provider=azure",
        "tag_name=ConsulAutoJoin",
        "tag_value=auto-join",
        "subscription_id=${var.subscription_id}",
        "tenant_id=${var.tenant_id}",
        "client_id=${var.client_id}",
        "secret_access_key=${var.client_secret}",
      ])
      nomad_binary              = var.nomad_binary
      nomad_consul_token_id     = random_uuid.nomad_consul_token_id.id
      nomad_consul_token_secret = random_uuid.nomad_consul_token_secret.id
      nomad_acl_enabled         = var.nomad_acl_enabled
      consul_acl_enabled        = var.consul_acl_enabled
  }))}"

  disable_password_authentication = false
}