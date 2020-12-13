provider "azurerm" {
  features {}
}


#Network
resource "azurerm_resource_group" "vti" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_network_security_group" "vti" {
  name                = "SG"
  location            = azurerm_resource_group.vti.location
  resource_group_name = azurerm_resource_group.vti.name

  security_rule {
    name                       = "sg"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "sg1"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags

}


resource "azurerm_virtual_network" "vti" {
  name                = "vti-vnet"
  address_space       = ["192.168.1.0/24"]
  location            = var.location
  resource_group_name = azurerm_resource_group.vti.name
  tags                = var.tags
}

resource "azurerm_subnet" "vti1" {
  name                 = "vti-subnet1"
  resource_group_name  = azurerm_resource_group.vti.name
  virtual_network_name = azurerm_virtual_network.vti.name
  address_prefixes     = ["192.168.1.0/25"]
}

resource "azurerm_subnet_network_security_group_association" "sb1_sg" {
  subnet_id                 = azurerm_subnet.vti1.id
  network_security_group_id = azurerm_network_security_group.vti.id
}

resource "azurerm_subnet" "vti2" {
  name                 = "vti-subnet2"
  resource_group_name  = azurerm_resource_group.vti.name
  virtual_network_name = azurerm_virtual_network.vti.name
  address_prefixes     = ["192.168.1.128/25"]
}
resource "azurerm_subnet_network_security_group_association" "sb2_sg" {
  subnet_id                 = azurerm_subnet.vti2.id
  network_security_group_id = azurerm_network_security_group.vti.id
}


resource "azurerm_public_ip" "vti" {
  name                = "vti-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.vti.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
  domain_name_label   = "vti"

}


resource "azurerm_public_ip" "vm1" {
  name                = "vm1"
  location            = var.location
  resource_group_name = azurerm_resource_group.vti.name
  allocation_method   = "Static"
  tags                = var.tags
  sku                 = "Standard"

  zones = ["1"]

}

resource "azurerm_public_ip" "vm2" {
  name                = "vm2"
  location            = var.location
  resource_group_name = azurerm_resource_group.vti.name
  allocation_method   = "Static"
  tags                = var.tags
  sku                 = "Standard"

  zones = ["2"]

}



#-------------------Load Balancer-------------------------
resource "azurerm_lb" "vti" {
  name                = "vti-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.vti.name
  sku                 = "Standard"




  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vti.id

  }

  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = azurerm_resource_group.vti.name
  loadbalancer_id     = azurerm_lb.vti.id
  name                = "BackEndAddressPool"

}

resource "azurerm_lb_probe" "vti" {
  resource_group_name = azurerm_resource_group.vti.name
  loadbalancer_id     = azurerm_lb.vti.id
  name                = "ssh-running-probe"
  port                = var.application_port
}

resource "azurerm_lb_rule" "lbnatrule" {
  resource_group_name            = azurerm_resource_group.vti.name
  loadbalancer_id                = azurerm_lb.vti.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = var.application_port
  backend_port                   = var.application_port
  backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool.id
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.vti.id
}



#---------------VM1 create--------------------------
resource "azurerm_network_interface" "nic1" {
  name                = "nic1"
  location            = var.location
  resource_group_name = azurerm_resource_group.vti.name

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = azurerm_subnet.vti1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm1.id


  }
}

resource "azurerm_network_interface_backend_address_pool_association" "nic1" {
  network_interface_id    = azurerm_network_interface.nic1.id
  ip_configuration_name   = "IPConfiguration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bpepool.id
}



resource "azurerm_virtual_machine" "vti" {
  name                  = "vm1"
  location              = var.location
  resource_group_name   = azurerm_resource_group.vti.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [azurerm_network_interface.nic1.id]
  zones                 = ["1"]




  delete_os_disk_on_termination = true


  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "mydisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }


  os_profile {
    computer_name  = "vmlab"
    admin_username = var.admin_user
    custom_data    = file("web.conf")
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file("~/.ssh/id_rsa.pub")
      path     = "/home/azureuser/.ssh/authorized_keys"
    }

  }

  tags = var.tags
}



#---------------VM2 create--------------------------

resource "azurerm_network_interface" "nic2" {
  name                = "nic2"
  location            = var.location
  resource_group_name = azurerm_resource_group.vti.name
  ip_configuration {
    name                          = "IPConfiguration2"
    subnet_id                     = azurerm_subnet.vti2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm2.id


  }
}

resource "azurerm_network_interface_backend_address_pool_association" "nic2" {
  network_interface_id    = azurerm_network_interface.nic2.id
  ip_configuration_name   = "IPConfiguration2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bpepool.id
}



resource "azurerm_virtual_machine" "vti2" {
  name                  = "vm2"
  location              = var.location
  resource_group_name   = azurerm_resource_group.vti.name
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [azurerm_network_interface.nic2.id]
  zones                 = ["2"]




  delete_os_disk_on_termination = true


  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "mydisk2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }


  os_profile {
    computer_name  = "vmlab2"
    admin_username = var.admin_user
    custom_data    = file("web2.conf")
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file("~/.ssh/id_rsa.pub")
      path     = "/home/azureuser/.ssh/authorized_keys"
    }
  }


  tags = var.tags
}
