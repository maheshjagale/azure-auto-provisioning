
variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "vm_count" {
  description = "Number of virtual machines to create"
  type        = number
  default     = 1
  
  validation {
    condition     = var.vm_count > 0 && var.vm_count <= 10
    error_message = "VM count must be between 1 and 10."
  }
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "os_type" {
  description = "Operating system type (linux or windows)"
  type        = string
  default     = "linux"
  
  validation {
    condition     = contains(["linux", "windows"], var.os_type)
    error_message = "OS type must be linux or windows."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
