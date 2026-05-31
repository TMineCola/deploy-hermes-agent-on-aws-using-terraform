[English](../../README.md) | [繁體中文](README.md)

# Hermes Agent

部署在 AWS EC2 上的 Telegram 個人助理，使用 Amazon Bedrock Claude Opus 4.6 作為 AI 引擎。

## 專案結構

```
.
├── docs/
│   ├── en/
│   └── zh-TW/
├── terraform/
│   ├── main.tf                       # Provider 設定
│   ├── variables.tf                  # 變數定義
│   ├── vpc.tf                        # VPC / Subnet / NAT
│   ├── security_groups.tf            # Security Groups
│   ├── iam.tf                        # IAM Role / Policy
│   ├── vpc_endpoints.tf              # VPC Endpoints (PrivateLink)
│   ├── ec2.tf                        # EC2 Instance
│   ├── ssm.tf                        # SSM Parameters (Secrets)
│   ├── monitoring.tf                 # VPC Flow Logs → S3
│   ├── athena.tf                     # Athena Workgroup / Glue Catalog
│   ├── outputs.tf                    # Outputs
│   ├── user_data.sh                  # EC2 User Data Script
│   └── terraform.tfvars.example      # 變數範例
└── README.md
```

## Quick Start

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# 編輯 terraform.tfvars 填入 telegram_bot_token 和 telegram_allowed_users

terraform init
terraform plan
terraform apply
```

## Tech Stack

- **執行環境**: Python 3.11，Amazon Linux 2023 (ARM64/Graviton)
- **AI 模型**: Amazon Bedrock (Claude Opus 4.6, Global Cross-Region Inference)
- **Hermes Agent**: v0.14.0 (git installer，追蹤 main branch)
- **基礎設施**: Terraform (AWS Provider ~> 5.0)
- **部署區域**: 預設 ap-northeast-1 (東京)，可透過變數調整
- **日誌**: VPC Flow Logs v3 → S3 → Athena

## ⚠️ 費用提醒

> **請謹慎選擇模型，並注意模型 Token 相關費用。**
>
> 大型語言模型（尤其是 Opus 等級）的 Token 費用可能相當高昂。請監控 Amazon Bedrock 用量並設定帳單警報，以避免產生非預期的費用。若使用情境對成本較敏感，可考慮改用較輕量的模型（如 Sonnet 或 Haiku）。

## Security Features

- EC2 零入站規則 (Telegram 採取 Long Polling)
- Hermes Agent 以非特權用戶 (`hermes`) 運行
- Bedrock API 透過 VPC Endpoint (PrivateLink) 存取，不經公網
- 強制 IMDSv2、EBS 磁碟加密
- 使用 SSM Session Manager 取代 SSH
- 最小權限 IAM Policy
- VPC Flow Logs (v3) 網路流量審計
- 機密資訊透過 SSM Parameter Store (SecureString) 管理

## Documentation

- [系統架構](system-architecture.md)
- [網路架構](network-architecture.md)
- [部署流程](deployment-guide.md)
- [Athena 查詢樣板](athena-queries.md)
- [參考資料](references.md)
