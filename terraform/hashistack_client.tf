# resource "azurerm_public_ip" "hashistack-client-public-ip" {
#   count                        = "${var.client_count}"
#   name                         = "hashistack-client-ip-${count.index}"
#   location                     = "${var.location}"
#   resource_group_name          = "${data.azurerm_resource_group.nf-nomad.name}"
#   allocation_method             = "Static"
# }

resource "azurerm_network_interface" "hashistack-client-ni" {
  count                     = "${var.client_count}"
  name                      = "hashistack-client-ni-${count.index}"
  location                  = "${var.location}"
  resource_group_name       = "${data.azurerm_resource_group.nf-nomad.name}"

  ip_configuration {
    name                          = "hashistack-ipc"
    subnet_id                     = "${azurerm_subnet.hashistack-sn.id}"
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = "${element(azurerm_public_ip.hashistack-client-public-ip.*.id, count.index)}"
  }

  tags                            = {"ConsulAutoJoin" = "auto-join"}
}

resource "random_string" "client_admin_password" {
  length = 16
}

resource "azurerm_linux_virtual_machine" "client" {
  name                  = "hashistack-client-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${data.azurerm_resource_group.nf-nomad.name}"
  network_interface_ids = ["${element(azurerm_network_interface.hashistack-client-ni.*.id, count.index)}"]
  size                  = "${var.client_instance_type}"
  count                 = "${var.client_count}"
  depends_on            = [azurerm_linux_virtual_machine.server]

  boot_diagnostics {
    storage_account_uri = "https://${data.azurerm_storage_account.hashistack_job.name}.blob.core.windows.net/"
  }

  source_image_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Compute/images/${var.image_name}"

  os_disk {
    name              = "hashistack-client-osdisk-${count.index}"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  computer_name  = "hashistack-client-${count.index}"
  admin_username = "ubuntu"
  admin_password = random_string.server_admin_password.result
  custom_data    = "${base64encode(templatefile("${path.module}/../shared/data-scripts/user-data-client.sh", {
      region                    = var.location
      cloud_env                 = "azure"
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
      nomad_consul_token_secret = random_uuid.nomad_consul_token_secret.id
  }))}"
  
  disable_password_authentication = false
}