# locals.tf

locals {
  # 이 프로젝트의 모든 리소스 이름 앞에 붙일 공통 접두사
  prefix = "gtm-ent-metafree"

  # 모든 리소스에 일관되게 적용할 공통 태그
  common_tags = {
    Project   = "GTM-Enterprise"
    Owner     = "InfraTeam"
    ManagedBy = "Terraform"
  }

/*
  # --- Cloud-init 스크립트 부품들 ---
  cloud_init_script_net_tools = <<-EOF
    #!/bin/bash
    sudo dnf update -y
    sudo dnf install -y net-tools
    echo "net-tools installed successfully." > /var/log/cloud-init-net-tools.log
    EOF

  cloud_init_script_jdk_11 = <<-EOF
    #!/bin/bash
    sudo dnf install -y java-11-openjdk-devel
    echo "JDK 11 installed successfully." > /var/log/cloud-init-jdk.log
    java -version >> /var/log/cloud-init-jdk.log 2>&1
    EOF
*/
}
