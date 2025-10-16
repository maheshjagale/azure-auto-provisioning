# Terraform Outputs - Information exposed after provisioning

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "vm_names" {
  description = "Names of all created virtual machines"
  value       = var.os_type == "linux" ? azurerm_linux_virtual_machine.main[*].name : azurerm_windows_virtual_machine.main[*].name
}

output "vm_public_ips" {
  description = "Public IP addresses of all VMs"
  value       = azurerm_public_ip.main[*].ip_address
}

output "vm_private_ips" {
  description = "Private IP addresses of all VMs"
  value       = azurerm_network_interface.main[*].private_ip_address
}

output "admin_username" {
  description = "Admin username for VMs"
  value       = var.admin_username
}

output "admin_password" {
  description = "Admin password for VMs (sensitive)"
  value       = random_password.vm_password.result
  sensitive   = true
}

output "connection_commands" {
  description = "Commands to connect to each VM"
  value = var.os_type == "linux" ? [
    for i, ip in azurerm_public_ip.main[*].ip_address :
    "ssh ${var.admin_username}@${ip}"
  ] : [
    for i, ip in azurerm_public_ip.main[*].ip_address :
    "mstsc /v:${ip}"
  ]
}

output "provisioning_summary" {
  description = "Summary of provisioned infrastructure"
  value = {
    environment     = var.environment
    project_name    = var.project_name
    location        = var.location
    vm_count        = var.vm_count
    vm_size         = var.vm_size
    os_type         = var.os_type
    creation_time   = timestamp()
  }
}
