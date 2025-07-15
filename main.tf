# -----------------------------------------------------------------------------
# 리소스 생성 (main.tf 내용)
# -----------------------------------------------------------------------------

# Azure Provider 설정
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.99.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {}
}

# --- 리소스 그룹 ---
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# --- 가상 네트워크 (VNet) 및 서브넷 ---
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.prefix}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "web_subnet" {
  name                 = "web-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.web_subnet_prefix]
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.app_subnet_prefix]
}

resource "azurerm_subnet" "jumpbox_subnet" {
  name                 = "jumpbox-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# --- 공용 IP 주소 ---
resource "azurerm_public_ip" "appgw_public_ip" {
  name                = "${local.prefix}-pip-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_public_ip" "jumpbox_public_ip" {
  name                = "${local.prefix}-pip-jumpbox"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# --- 네트워크 보안 그룹 (NSG) 및 연결 ---
resource "azurerm_network_security_group" "web_nsg" {
  name                = "${local.prefix}-nsg-web"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowHttpInFromAppGateway"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = azurerm_subnet.appgw_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web_nsg_assoc" {
  subnet_id                 = azurerm_subnet.web_subnet.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

resource "azurerm_network_security_group" "app_nsg" {
  name                = "${local.prefix}-nsg-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowTomcatInFromWebSubnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080" # Tomcat Port
    source_address_prefix      = azurerm_subnet.web_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app_nsg_assoc" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

resource "azurerm_network_security_group" "jumpbox_nsg" {
  name                = "${local.prefix}-nsg-jumpbox"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowRdpInFromMyIp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    # [보안 권장] 운영 환경에서는 "Internet" 대신 특정 관리자 IP로 제한해야 합니다.
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "jumpbox_nsg_assoc" {
  subnet_id                 = azurerm_subnet.jumpbox_subnet.id
  network_security_group_id = azurerm_network_security_group.jumpbox_nsg.id
}

# --- 가용성 세트 ---
resource "azurerm_availability_set" "web_as" {
  name                         = "${local.prefix}-as-web"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
  tags                         = local.common_tags
}

resource "azurerm_availability_set" "app_as" {
  name                         = "${local.prefix}-as-app"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
  tags                         = local.common_tags
}

# --- 네트워크 인터페이스 (NIC) ---
resource "azurerm_network_interface" "web_nic" {
  name                = "${local.prefix}-nic-web-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "app_nic" {
  name                = "${local.prefix}-nic-app-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "jumpbox_nic" {
  name                = "${local.prefix}-nic-jumpbox"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.jumpbox_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox_public_ip.id
  }
}

/*
# --- Cloud-init 설정 정의 ---
# WEB VM용 cloud-init: net-tools만 설치
data "cloudinit_config" "web_vm_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "install-net-tools.sh"
    content_type = "text/x-shellscript"
    content      = local.cloud_init_script_net_tools
  }
}

# APP VM용 cloud-init: net-tools와 JDK 11 모두 설치
data "cloudinit_config" "app_vm_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "install-net-tools.sh"
    content_type = "text/x-shellscript"
    content      = local.cloud_init_script_net_tools
  }
  part {
    filename     = "install-jdk.sh"
    content_type = "text/x-shellscript"
    content      = local.cloud_init_script_jdk_11
  }
}
*/

# --- 가상 머신 (VMs) ---
resource "azurerm_linux_virtual_machine" "web_vm" {
  name                  = "${local.prefix}-vm-web-01"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = var.web_vm_size
  admin_username        = var.vm_admin_username
  availability_set_id   = azurerm_availability_set.web_as.id
  network_interface_ids = [azurerm_network_interface.web_nic.id]
  tags                  = local.common_tags

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "8-lvm"
    version   = "latest"
  }
  plan {
    name      = "8-lvm"
    publisher = "resf"
    product   = "rockylinux-x86_64"
  }

#  custom_data = data.cloudinit_config.web_vm_init.rendered
}

resource "azurerm_linux_virtual_machine" "app_db_vm" {
  name                  = "${local.prefix}-vm-app-db-01"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = var.app_db_vm_size
  admin_username        = var.vm_admin_username
  availability_set_id   = azurerm_availability_set.app_as.id
  network_interface_ids = [azurerm_network_interface.app_nic.id]
  tags                  = local.common_tags

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 1024
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "8-lvm"
    version   = "latest"
  }
  plan {
    name      = "8-lvm"
    publisher = "resf"
    product   = "rockylinux-x86_64"
  }

#  custom_data = data.cloudinit_config.app_vm_init.rendered
}

resource "azurerm_windows_virtual_machine" "jumpbox_vm" {
  name                  = "${local.prefix}-vm-jumpbox"
  computer_name         = "jumpboxvm"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = var.jumpbox_vm_size
  admin_username        = var.vm_admin_username
  admin_password        = var.vm_admin_password
  network_interface_ids = [azurerm_network_interface.jumpbox_nic.id]
  tags                  = local.common_tags

  os_disk {
    name                 = "${local.prefix}-jumpbox-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-23h2-ent"
    version   = "latest"
  }
}

# --- Application Gateway (WAF) ---
resource "azurerm_application_gateway" "appgw" {
  name                = "${local.prefix}-appgw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.common_tags

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = var.appgw_sku_capacity
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.appgw_public_ip.id
  }

  backend_address_pool {
    name         = "web-backend-pool"
    ip_addresses = [azurerm_network_interface.web_nic.private_ip_address]
  }

  backend_http_settings {
    name                  = "web-backend-http-setting"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip-config"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule-http"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "web-backend-pool"
    backend_http_settings_name = "web-backend-http-setting"
    priority                   = 100
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = var.appgw_waf_firewall_mode
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }
}
