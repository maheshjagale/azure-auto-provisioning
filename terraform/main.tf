# Main Terraform Configuration for Azure VM Provisioning

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  
  # Backend for storing Terraform state in Azure
  # This keeps track of what infrastructure exists
  backend "azurerm" {
    resource_group_name  = "azure-rg1"
    storage_account_name = "maheshstorage29"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Generate random suffix for unique naming
resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Generate random password for VMs
resource "random_password" "vm_password" {
  length  = 16
  special = true
}

# Resource Group - Container for all resources
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    CreatedDate = timestamp()
  })
}

# Virtual Network - Private network for VMs
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = azurerm_resource_group.main.tags
}

# Subnet - Subdivision of virtual network
resource "azurerm_subnet" "main" {
  name                 = "subnet-${var.project_name}-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group - Firewall rules
resource "azurerm_network_security_group" "main" {
  name                = "nsg-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = azurerm_resource_group.main.tags
  
  # Allow SSH for Linux or RDP for Windows
  security_rule {
    name                       = "Allow-${var.os_type == "linux" ? "SSH" : "RDP"}"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.os_type == "linux" ? "22" : "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Allow HTTP
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  # Allow HTTPS
  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Public IP Addresses - One per VM
resource "azurerm_public_ip" "main" {
  count               = var.vm_count
  name                = "pip-${var.project_name}-${var.environment}-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = azurerm_resource_group.main.tags
}

# Network Interfaces - Connects VMs to network
resource "azurerm_network_interface" "main" {
  count               = var.vm_count
  name                = "nic-${var.project_name}-${var.environment}-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = azurerm_resource_group.main.tags
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main[count.index].id
  }
}

# Connect NSG to Network Interfaces
resource "azurerm_network_interface_security_group_association" "main" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.main[count.index].id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Virtual Machines
resource "azurerm_linux_virtual_machine" "main" {
  count               = var.os_type == "linux" ? var.vm_count : 0
  name                = "vm-${var.project_name}-${var.environment}-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.vm_password.result
  
  disable_password_authentication = false
  
  network_interface_ids = [
    azurerm_network_interface.main[count.index].id
  ]
  
  os_disk {
    name                 = "osdisk-${var.project_name}-${var.environment}-${count.index + 1}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  
  tags = azurerm_resource_group.main.tags
}

resource "azurerm_windows_virtual_machine" "main" {
  count               = var.os_type == "windows" ? var.vm_count : 0
  name                = "vm-${var.project_name}-${var.environment}-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.vm_password.result
  
  network_interface_ids = [
    azurerm_network_interface.main[count.index].id
  ]
  
  os_disk {
    name                 = "osdisk-${var.project_name}-${var.environment}-${count.index + 1}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
  
  tags = azurerm_resource_group.main.tags
}

