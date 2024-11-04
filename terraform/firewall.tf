resource "azurerm_network_security_group" "hashistack-sg" {
  name                = "hashistack-sg"
  location            = "${var.location}"
  resource_group_name = "${data.azurerm_resource_group.nf-nomad.name}"
}

resource "azurerm_subnet_network_security_group_association" "hashistack-sg-association" {
  subnet_id                 = azurerm_subnet.hashistack-sn.id
  network_security_group_id = azurerm_network_security_group.hashistack-sg.id
}

resource "azurerm_network_interface_security_group_association" "hashistack-ni-client-sg-association" {
  count                     = var.client_count
  network_interface_id      = "${element(azurerm_network_interface.hashistack-client-ni.*.id, count.index)}"
  network_security_group_id = azurerm_network_security_group.hashistack-sg.id
}

resource "azurerm_network_interface_security_group_association" "hashistack-ni-server-sg-association" {
  count                     = var.server_count
  network_interface_id      = "${element(azurerm_network_interface.hashistack-server-ni.*.id, count.index)}"
  network_security_group_id = azurerm_network_security_group.hashistack-sg.id
}

resource "azurerm_network_security_rule" "nomad_ui_ingress" {
  name                        = "nfnomad-nomad-ui-ingress"
  resource_group_name         = "${data.azurerm_resource_group.nf-nomad.name}"
  network_security_group_name = "${azurerm_network_security_group.hashistack-sg.name}"

  priority  = 101
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = data.azurerm_virtual_network.nf-nomad-vn.address_space[0]
  source_port_range          = "*"
  destination_port_range     = "4646"
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "consul_ui_ingress" {
  name                        = "nfnomad-consul-ui-ingress"
  resource_group_name         = "${data.azurerm_resource_group.nf-nomad.name}"
  network_security_group_name = "${azurerm_network_security_group.hashistack-sg.name}"

  priority  = 102
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = data.azurerm_virtual_network.nf-nomad-vn.address_space[0]
  source_port_range          = "*"
  destination_port_range     = "8500"
  destination_address_prefix = "*"
}

# resource "azurerm_network_security_rule" "ssh_ingress" {
#   name                        = "nfnomad-ssh-ingress"
#   resource_group_name         = "${data.azurerm_resource_group.nf-nomad.name}"
#   network_security_group_name = "${azurerm_network_security_group.hashistack-sg.name}"

#   priority  = 100
#   direction = "Inbound"
#   access    = "Allow"
#   protocol  = "Tcp"

#   source_address_prefix      = data.azurerm_virtual_network.nf-nomad-vn.address_space[0]
#   source_port_range          = "*"
#   destination_port_range     = "22"
#   destination_address_prefix = "*"
# }

resource "azurerm_network_security_rule" "allow_all_internal" {
  name                        = "nfnomad-allow-all-internal"
  resource_group_name         = "${data.azurerm_resource_group.nf-nomad.name}"
  network_security_group_name = "${azurerm_network_security_group.hashistack-sg.name}"

  priority  = 103
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = azurerm_subnet.hashistack-sn.address_prefixes[0]
  source_port_range          = "*"
  destination_port_range     = "*"
  destination_address_prefix = azurerm_subnet.hashistack-sn.address_prefixes[0]
}

# resource "azurerm_network_security_rule" "clients_ingress" {
#   name                        = "nfnomad-clients-ingress"
#   resource_group_name         = "${data.azurerm_resource_group.nf-nomad.name}"
#   network_security_group_name = "${azurerm_network_security_group.hashistack-sg.name}"

#   priority  = 110
#   direction = "Inbound"
#   access    = "Allow"
#   protocol  = "Tcp"

#   # Add application ingress rules here
#   # These rules are applied only to the client nodes

#   # nginx example; replace with your application port
#   source_address_prefix      = data.azurerm_virtual_network.nf-nomad-vn.address_space[0]
#   source_port_range          = "*"
#   destination_port_range     = "80"
#   destination_address_prefixes = azurerm_linux_virtual_machine.client[*].public_ip_address
# }