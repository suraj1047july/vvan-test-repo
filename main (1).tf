
# =============================================================================
# Azure Virtual WAN - Complete Infrastructure
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
cloud {
    organization = "terraform_learn_all_cloud"
    workspaces {
      name ="Disconnected-Env"
    }
}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-insecure-demo"
  location = "East US"
}

# ❌ Storage Account without secure settings
resource "azurerm_storage_account" "insecure_storage" {
  name                     = "insecurestoragedemo123"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # ❌ Missing secure transfer enforcement
  enable_https_traffic_only = false

  # ❌ No encryption block explicitly defined
}

# ❌ Network Security Group with open access
resource "azurerm_network_security_group" "open_nsg" {
  name                = "open-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-All-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"      # ❌ open to world
    destination_address_prefix = "*"
  }
}

# ❌ Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "demo-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# ❌ Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "demo-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ❌ Public IP (internet exposure)
resource "azurerm_public_ip" "public_ip" {
  name                = "demo-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# ❌ Network Interface
resource "azurerm_network_interface" "nic" {
  name                = "demo-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# ❌ VM with weak security
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "insecure-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"

  # ❌ Password auth enabled (should use SSH keys)
  admin_password = "WeakPassword123!"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}
