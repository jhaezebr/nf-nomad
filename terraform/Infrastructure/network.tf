data "azurerm_virtual_network" "nf-nomad-vn" {
  name                = "nf-nomad-vn"
  resource_group_name = "${data.azurerm_resource_group.nf-nomad.name}"
}

resource "azurerm_subnet" "hashistack-sn" {
  name                 = "hashistack-sn"
  resource_group_name  = "${data.azurerm_resource_group.nf-nomad.name}"
  virtual_network_name = "${data.azurerm_virtual_network.nf-nomad-vn.name}"
  address_prefixes       = ["10.0.2.0/24"]
}
