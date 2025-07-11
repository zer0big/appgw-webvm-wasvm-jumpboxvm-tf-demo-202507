# outputs.tf
output "application_gateway_public_ip" {
  description = "The public IP address of the Application Gateway."
  value       = azurerm_public_ip.appgw_public_ip.ip_address
}

output "jumpbox_public_ip" {
  description = "The public IP address of the Jumpbox VM."
  value       = azurerm_public_ip.jumpbox_public_ip.ip_address
}

output "web_rocky_vm_private_ip" { # Output 이름 변경: web_ubuntu_vm -> web_rocky_vm
  description = "The private IP address of the Web Rocky Linux VM (Apache)."
  value       = azurerm_network_interface.web_rocky_nic.private_ip_address # NIC 참조 변경
}

output "app_rocky_vm_private_ip" { # Output 이름 변경: app_ubuntu_vm -> app_rocky_vm
  description = "The private IP address of the App Rocky Linux VM (Tomcat)."
  value       = azurerm_network_interface.app_rocky_nic.private_ip_address # NIC 참조 변경
}
