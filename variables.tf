# -----------------------------------------------------------------------------
# 일반 설정 (General Settings)
# -----------------------------------------------------------------------------
variable "resource_group_name" {
  description = "생성할 리소스 그룹의 이름"
  type        = string
  default     = "rg-appgw-3tier-archi-demo"
}

variable "location" {
  description = "리소스를 배포할 Azure 지역"
  type        = string
  default     = "Korea Central"
}

# -----------------------------------------------------------------------------
# 네트워크 설정 (Network Settings)
# -----------------------------------------------------------------------------
variable "web_subnet_prefix" {
  description = "Web Tier 서브넷의 주소 대역"
  type        = string
  default     = "10.0.3.0/24"
}

variable "app_subnet_prefix" {
  description = "App/DB Tier 서브넷의 주소 대역"
  type        = string
  default     = "10.0.4.0/24"
}

# -----------------------------------------------------------------------------
# Application Gateway 설정 (Application Gateway Settings)
# -----------------------------------------------------------------------------
variable "appgw_sku_capacity" {
  description = "Application Gateway WAF v2의 용량 단위(Capacity Unit)"
  type        = number
  default     = 2
}

variable "appgw_waf_firewall_mode" {
  description = "Application Gateway WAF의 방화벽 모드 (Prevention 또는 Detection)"
  type        = string
  default     = "Prevention"
}

# -----------------------------------------------------------------------------
# 가상 머신 설정 (Virtual Machine Settings)
# -----------------------------------------------------------------------------
variable "web_vm_size" {
  description = "배포할 가상 머신의 크기"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "app_db_vm_size" {
  description = "배포할 가상 머신의 크기"
  type        = string
#  default     = "Standard_D32s_v5"
  default     = "Standard_D4s_v5"
}

variable "jumpbox_vm_size" {
  description = "배포할 가상 머신의 크기"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_admin_username" {
  description = "가상 머신에 생성할 관리자 계정 이름"
  type        = string
  default     = "prjadmin"
}

variable "vm_admin_password" {
  description = "가상 머신에 생성할 관리자 계정의 암호 (Windows VM에 필수)"
  type        = string
  sensitive   = true # 민감 정보 출력 숨김
  default     = " " # [보안 권장] PROD 환경에서는 하드코딩 하지 말 것!!!
}

variable "ssh_public_key_path" {
  description = "VM 접속에 사용할 SSH 공개 키 파일의 경로"
  type        = string
  # 중요: 이 경로는 terraform을 실행하는 사용자 PC의 실제 경로와 일치해야 함.
  # 예: "~/.ssh/id_rsa.pub"
  default     = "~/.ssh/id_rsa.pub"
}
