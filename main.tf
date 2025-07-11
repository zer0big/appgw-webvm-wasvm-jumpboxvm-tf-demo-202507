# Azure Provider 설정
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.99.0" # Provider 버전을 3.99.0으로 명시적으로 고정
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
}

# --- 가상 네트워크 (VNet) ---
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-gtm-ent-metafree"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# --- 서브넷 (각각 독립적인 리소스) ---
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "web_subnet" {
  name                 = "web_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.web_subnet_prefix]
}

# App Tier (Tomcat) 서브넷
resource "azurerm_subnet" "app_subnet" {
  name                 = "app_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.app_subnet_prefix]
}

# DB Tier 서브넷 - 주석 처리
/*
resource "azurerm_subnet" "db_subnet" {
  name                 = "db_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.db_subnet_prefix]
}
*/

resource "azurerm_subnet" "jumpbox_subnet" {
  name                 = "jumpbox_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# --- 공용 IP 주소들 ---
resource "azurerm_public_ip" "appgw_public_ip" {
  name                = "pip-appgw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "jumpbox_public_ip" {
  name                = "pip-jumpbox"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# --- 네트워크 보안 그룹 (NSG) 및 연결 ---
# App Gateway 서브넷용 NSG
resource "azurerm_network_security_group" "appgw_nsg" {
  name                = "nsg-appgw-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowPublicHTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowPublicHTTPS"
    priority                   = 210
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "appgw_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.appgw_subnet.id
  network_security_group_id = azurerm_network_security_group.appgw_nsg.id
}

# Web 서브넷용 NSG
resource "azurerm_network_security_group" "web_nsg" {
  name                = "nsg-web-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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
  security_rule {
    name                       = "AllowSshInFromJumpbox"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_subnet.jumpbox_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.web_subnet.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

# App 서브넷용 NSG - 주석 처리
resource "azurerm_network_security_group" "app_nsg" {
  name                = "nsg-app-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowTomcatInFromWebSubnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080" # Tomcat 기본 포트
    source_address_prefix      = azurerm_subnet.web_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowSshInFromJumpbox"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_subnet.jumpbox_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
}

# App 서브넷 NSG 연결 - 주석 처리
resource "azurerm_subnet_network_security_group_association" "app_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

# DB 서브넷용 NSG - 주석 처리
/*
resource "azurerm_network_security_group" "db_nsg" {
  name                = "nsg-db-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowMysqlInFromAppSubnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306" # MySQL/MariaDB 기본 포트
    source_address_prefix      = azurerm_subnet.app_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowSshInFromJumpbox"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_subnet.jumpbox_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
}
*/

# DB 서브넷 NSG 연결 - 주석 처리
/*
resource "azurerm_subnet_network_security_group_association" "db_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.db_subnet.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}
*/

# Jumpbox 서브넷용 NSG
resource "azurerm_network_security_group" "jumpbox_nsg" {
  name                = "nsg-jumpbox-subnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowRdpInFromInternet" # RDP 포트 허용 규칙 이름 변경
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389" # RDP 기본 포트
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "jumpbox_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.jumpbox_subnet.id
  network_security_group_id = azurerm_network_security_group.jumpbox_nsg.id
}


# --- Application Gateway (WAF) ---
resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-gtm-ent-metafree"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

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

  # 백엔드 풀: 이제 web_rocky_nic의 private_ip_address를 참조
  backend_address_pool {
    name         = "backend-pool-http"
    ip_addresses = [azurerm_network_interface.web_rocky_nic.private_ip_address]
  }

  backend_http_settings {
    name                  = "backend-http-setting"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "http-probe-internal"
  }

  http_listener {
    name                         = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip-config"
    frontend_port_name           = "http-port"
    protocol                     = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule-http"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool-http"
    backend_http_settings_name = "backend-http-setting"
    priority                   = 100
  }

  waf_configuration {
    enabled        = true
    firewall_mode  = var.appgw_waf_firewall_mode
    rule_set_type  = "OWASP"
    rule_set_version = "3.2"
  }

  probe {
    name                = "http-probe-internal"
    protocol            = "Http"
    host                = "127.0.0.1"
    path                = "/"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
  }

  depends_on = [azurerm_network_security_group.appgw_nsg]
}

# --- 가용성 세트 ---
resource "azurerm_availability_set" "web_rocky_as" {
  name                         = "as-web-rocky"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

# App 가용성 세트
resource "azurerm_availability_set" "app_rocky_as" {
  name                         = "as-app-rocky"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

# DB 가용성 세트 - 주석 처리
/*
resource "azurerm_availability_set" "db_rocky_as" {
  name                         = "as-db-rocky"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}
*/

# Web 네트워크 인터페이스
resource "azurerm_network_interface" "web_rocky_nic" {
  name                = "nic-web-rocky-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# App 네트워크 인터페이스
resource "azurerm_network_interface" "app_rocky_nic" {
  name                = "nic-app-rocky-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# DB 네트워크 인터페이스 - 주석 처리
/*
resource "azurerm_network_interface" "db_rocky_nic" {
  name                = "nic-db-rocky-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.db_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
*/

resource "azurerm_network_interface" "jumpbox_nic" {
  name                = "nic-jumpbox"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.jumpbox_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox_public_ip.id
  }
}

# Web NIC NSG 연결
resource "azurerm_network_interface_security_group_association" "web_nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.web_rocky_nic.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

# App NIC NSG 연결
resource "azurerm_network_interface_security_group_association" "app_nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.app_rocky_nic.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

# DB NIC NSG 연결 - 주석 처리
/*
resource "azurerm_network_interface_security_group_association" "db_nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.db_rocky_nic.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}
*/

resource "azurerm_network_interface_security_group_association" "jumpbox_nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.jumpbox_nic.id
  network_security_group_id = azurerm_network_security_group.jumpbox_nsg.id
}

# --- Cloud-init 스크립트 (Rocky Linux용으로 수정 필요) ---

data "cloudinit_config" "apache_cloud_init" {
  gzip          = true
  base64_encode = true
  part {
    filename     = "apache-install.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
              #!/bin/bash
              # Rocky Linux (RHEL/CentOS) 환경에 맞게 수정 필요
              # 예: Apache HTTP Server (httpd) 설치 및 설정
              sudo dnf update -y
              sudo dnf install -y httpd
              sudo systemctl enable httpd
              sudo systemctl start httpd
              # 간단한 웹 페이지 생성 (테스트용)
              echo "<h1>Hello from Rocky Linux Apache Web Server!</h1>" | sudo tee /var/www/html/index.html
              EOF
  }
}

# Tomcat Cloud-init - 주석 해제
data "cloudinit_config" "tomcat_cloud_init" {
  gzip          = true
  base64_encode = true
  part {
    filename     = "tomcat-install.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
              #!/bin/bash
              # Rocky Linux (RHEL/CentOS) 환경에 맞게 수정 필요
              # OpenJDK 11 설치 및 기본 설정
              sudo dnf update -y
              sudo dnf install -y java-11-openjdk-devel tomcat

              sudo alternatives --set java /usr/lib/jvm/java-11-openjdk/bin/java
              sudo alternatives --set javac /usr/lib/jvm/java-11-openjdk/bin/javac

              # Java 버전 확인 (로그에 기록)
              java -version >> /var/log/cloud-init-output.log 2>&1

              # Tomcat 서비스 시작 및 활성화
              # Tomcat 서비스 이름은 배포 방식에 따라 다를 수 있습니다.
              # 일반적으로 dnf로 설치시 'tomcat' 입니다.
              sudo systemctl enable tomcat
              sudo systemctl start tomcat

              # 간단한 웹 페이지 생성 (테스트용)
              echo "<h1>Hello from Rocky Linux Tomcat App Server!</h1>" | sudo tee /usr/share/tomcat/webapps/ROOT/index.html
              # Tomcat 기본 경로 확인 필요: /var/lib/tomcat/webapps/ROOT 또는 /usr/share/tomcat/webapps/ROOT
              EOF
  }
}

# MySQL 설치 시 주석 해제 (Rocky Linux용으로 수정) - 주석 처리
/*
data "cloudinit_config" "mysql_cloud_init" {
  gzip          = true
  base64_encode = true
  part {
    filename     = "mysql-install.sh"
    content_type = "text/x-shellscript"
    # 중요: 이 스크립트는 데모용이며, root 암호가 'password'로 하드코딩되어 있음.
    # 운영 환경에서는 Azure Key Vault 같은 보안 서비스를 사용하여 암호를 관리해야 함.
    content = <<-EOF
              #!/bin/bash
              # Rocky Linux (RHEL/CentOS) 환경에 맞게 수정 필요
              # MySQL 설치 (dnf 모듈 사용)
              sudo dnf update -y
              sudo dnf install -y @mysql
              sudo systemctl enable --now mysqld
              # MySQL 보안 설치 스크립트 실행 (대화형)
              # 이 부분은 자동화하기 어렵습니다. Cloud-init에서는 비대화형으로 설정하거나
              # 별도의 스크립트로 실행하는 것이 좋습니다.
              # sudo mysql_secure_installation
              # 또는 다음 명령으로 root 비밀번호만 설정 가능
              # sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'password';"

              # 외부(App Subnet)에서의 접속을 허용하도록 설정 변경
              # /etc/my.cnf 또는 /etc/mysql/my.cnf 경로 확인 필요
              sudo sed -i "s/127.0.0.1/0.0.0.0/g" /etc/my.cnf
              sudo systemctl restart mysqld
              EOF
  }
}
*/

# MariaDB 설치 시 주석 해제 (Rocky Linux용으로 수정) - 주석 처리
/*
data "cloudinit_config" "mariadb_cloud_init" {
  gzip          = true
  base64_encode = true
  part {
    filename     = "mariadb-install.sh"
    content_type = "text/x-shellscript"
    # 중요: 이 스크립트는 데모용이며, root 암호가 'password'로 하드코딩되어 있음.
    # 운영 환경에서는 Azure Key Vault 같은 보안 서비스를 사용하여 암호를 관리해야 함.
    content = <<-EOF
              #!/bin/bash
              # Rocky Linux (RHEL/CentOS) 환경에 맞게 수정 필요
              # MariaDB 설치
              sudo dnf update -y
              sudo dnf install -y mariadb-server
              sudo systemctl enable --now mariadb
              # 외부(App Subnet)에서의 접속을 허용하도록 설정 변경
              # /etc/my.cnf.d/mariadb-server.cnf 경로 확인 필요
              sudo sed -i "s/127.0.0.1/0.0.0.0/g" /etc/my.cnf.d/mariadb-server.cnf
              sudo systemctl restart mariadb
              EOF
  }
}
*/

# --- 가상 머신 (VMs) ---
resource "azurerm_linux_virtual_machine" "web_rocky_vm" {
  name                            = "web-rocky-vm-01"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.web_vm_size
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.web_rocky_nic.id]
  availability_set_id             = azurerm_availability_set.web_rocky_as.id

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = file(var.ssh_public_key_path)
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS" # ARM 템플릿은 Premium_LRS, 여기는 StandardSSD_LRS 유지
    disk_size_gb         = 128 # Web VM 디스크 크기 (D4 v5 사양에 맞게 128GB로 변경)
  }
  source_image_reference {
    publisher = "resf" # ARM 템플릿 기준
    offer     = "rockylinux-x86_64" # ARM 템플릿 기준
    sku       = "8-lvm" # ARM 템플릿 기준
    version   = "latest"
  }
  plan { # ARM 템플릿 기준
    name      = "8-lvm"
    publisher = "resf"
    product   = "rockylinux-x86_64"
  }
  custom_data = data.cloudinit_config.apache_cloud_init.rendered
}

# App VM
resource "azurerm_linux_virtual_machine" "app_rocky_vm" {
  name                            = "app-rocky-vm-01"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.app_db_vm_size
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.app_rocky_nic.id]
  availability_set_id             = azurerm_availability_set.app_rocky_as.id

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = file(var.ssh_public_key_path)
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS" # ARM 템플릿은 Premium_LRS, 여기는 StandardSSD_LRS 유지
    disk_size_gb         = 1024 # App VM 디스크 크기 (D32 v5 사양에 맞게 1024GB로 변경)
  }
  source_image_reference {
    publisher = "resf" # ARM 템플릿 기준
    offer     = "rockylinux-x86_64" # ARM 템플릿 기준
    sku       = "8-lvm" # ARM 템플릿 기준
    version   = "latest"
  }
  plan { # ARM 템플릿 기준
    name      = "8-lvm"
    publisher = "resf"
    product   = "rockylinux-x86_64"
  }
  custom_data = data.cloudinit_config.tomcat_cloud_init.rendered
}

# DB VM - 주석 처리
/*
resource "azurerm_linux_virtual_machine" "db_rocky_vm" {
  name                            = "db-rocky-vm-01"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.app_db_vm_size
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.db_rocky_nic.id]
  availability_set_id             = azurerm_availability_set.db_rocky_as.id

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = file(var.ssh_public_key_path)
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS" # ARM 템플릿은 Premium_LRS, 여기는 StandardSSD_LRS 유지
    disk_size_gb         = 1024 # DB VM 디스크 크기 (D32 v5 사양에 맞게 1024GB로 변경)
  }
  source_image_reference {
    publisher = "resf" # ARM 템플릿 기준
    offer     = "rockylinux-x86_64" # ARM 템플릿 기준
    sku       = "8-lvm" # ARM 템플릿 기준
    version   = "latest"
  }
  plan { # ARM 템플릿 기준
    name      = "8-lvm"
    publisher = "resf"
    product   = "rockylinux-x86_64"
  }
  # custom_data = data.cloudinit_config.mysql_cloud_init.rendered
  # custom_data = data.cloudinit_config.mariadb_cloud_init.rendered
}
*/

# --- Jumpbox VM (Windows) ---
resource "azurerm_windows_virtual_machine" "jumpbox_vm" {
  name                = "jumpbox-win-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.jumpbox_vm_size
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password

  network_interface_ids = [azurerm_network_interface.jumpbox_nic.id]

  os_disk {
    name                 = "jumpbox-win-osdisk"
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
