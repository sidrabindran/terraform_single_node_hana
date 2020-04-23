provider "azurerm" {
  version = "=2.0.0"
  features {}
}

# refer to a resource group
data "azurerm_resource_group" "rg" {
  name = "${var.rg}"
}

#refer to a subnet
data "azurerm_subnet" "subnet" {
  name                 = "${var.subnetname}"
  virtual_network_name = "${var.vnetname}"
  resource_group_name  = "${var.networkrg}"
}

# create a network interface to be attached
resource "azurerm_network_interface" "test" {
  name                = "${var.vmname}_nic"
  location            = "${var.location}"
  resource_group_name =  data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.vmname}_ipconfig"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
  }
}

#Create disk
resource "azurerm_managed_disk" "datadisk" {
  name                 = "${var.vmname}_datadisk_${count.index}"
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.datadisksize
  count                = var.datadiskcount
}

resource "azurerm_managed_disk" "logdisk" {
  name                 = "${var.vmname}_logdisk"
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.logdisksize
}

resource "azurerm_managed_disk" "shareddisk" {
  name                 = "${var.vmname}_shareddisk"
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.shareddisksize
}

# Create virtual machine
resource "azurerm_virtual_machine" "vm" {
    name                  = var.vmname
    location              = var.location
    resource_group_name   = data.azurerm_resource_group.rg.name
    network_interface_ids = ["${azurerm_network_interface.test.id}"]
    vm_size               = var.vmsize
    
# Uncomment this line to delete the OS disk automatically when deleting the VM
delete_os_disk_on_termination = true

# Uncomment this line to delete the data disks automatically when deleting the VM
delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = var.ospublisher
    offer     = var.osoffer
    sku       = var.ossku
    version   = var.osversion
  }
   storage_os_disk {
    name              = "${var.vmname}_osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }
  
   os_profile {
    computer_name  = var.vmname
    admin_username = var.admin
    admin_password = var.password
  }
   os_profile_linux_config {
    disable_password_authentication = false
  }

   admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

}
resource "azurerm_virtual_machine_data_disk_attachment" "datadisk" {
  count              = var.datadiskcount
  managed_disk_id    = element(azurerm_managed_disk.datadisk.*.id, count.index)
  virtual_machine_id = azurerm_virtual_machine.vm.id
  lun                = count.index
  caching            = "ReadOnly"
}

resource "azurerm_virtual_machine_data_disk_attachment" "logdisk" {
  managed_disk_id    = azurerm_managed_disk.logdisk.id
  virtual_machine_id = azurerm_virtual_machine.vm.id
  lun                = 2
  caching            = "None"
  write_accelerator_enabled = var.logdiskwa
}

resource "azurerm_virtual_machine_data_disk_attachment" "shareddisk" {
  managed_disk_id    = azurerm_managed_disk.shareddisk.id
  virtual_machine_id = azurerm_virtual_machine.vm.id
  lun                = 3
  caching            = "None"
}