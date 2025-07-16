# outputs.tf

output "web_vm_private_ip" {
  description = "Web VM Private IP Address"
  value       = azurerm_network_interface.web_nic.private_ip_address
}

output "app_db_vm_private_ip" {
  description = "App/DB VM Private IP Address"
  value       = azurerm_network_interface.app_nic.private_ip_address
}

output "jumpbox_vm_public_ip" {
  description = "Jumpbox VM Public IP Address"
  value       = azurerm_public_ip.jumpbox_public_ip.ip_address
}

output "application_gateway_public_ip" {
  description = "Application Gateway Public IP Address"
  value       = azurerm_public_ip.appgw_public_ip.ip_address
}
