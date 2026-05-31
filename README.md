[English](README.md) | [繁體中文](docs/zh-TW/README.md)

# Hermes Agent

A personal Telegram assistant deployed on AWS EC2, powered by Amazon Bedrock Claude Opus 4.6 as the AI engine.

## Project Structure

```
.
├── docs/
│   ├── en/
│   └── zh-TW/
├── terraform/
│   ├── main.tf                       # Provider Configuration
│   ├── variables.tf                  # Variable Definitions
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
│   └── terraform.tfvars.example      # Variable Example
└── README.md
```

## Quick Start

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your telegram_bot_token and telegram_allowed_users

terraform init
terraform plan
terraform apply
```

## Tech Stack

- **Runtime**: Python 3.11 on Amazon Linux 2023 (ARM64/Graviton)
- **AI Model**: Amazon Bedrock (Claude Opus 4.6, Global Cross-Region Inference)
- **Hermes Agent**: v0.14.0 (git installer, tracks main branch)
- **Infrastructure**: Terraform (AWS Provider ~> 5.0)
- **Region**: Default ap-northeast-1 (Tokyo), configurable via variables
- **Logging**: VPC Flow Logs v3 → S3 → Athena

## ⚠️ Cost Warning

> **Please choose your model carefully and be aware of token-related costs.**
>
> Large language models (especially Opus-tier) can incur significant per-token charges. Monitor your Amazon Bedrock usage and set billing alarms to avoid unexpected expenses. Consider switching to a lighter model (e.g., Sonnet or Haiku) for lower-cost scenarios.

## Security Features

- Zero inbound rules on EC2 (Telegram Long Polling)
- Hermes Agent runs as unprivileged user (`hermes`)
- Bedrock API accessed via VPC Endpoint (PrivateLink)
- IMDSv2 enforced, EBS encryption enabled
- SSM Session Manager replaces SSH
- Least-privilege IAM Policy
- VPC Flow Logs (v3) for auditing
- Secrets managed via SSM Parameter Store (SecureString)

## Documentation

- [System Architecture](docs/en/system-architecture.md)
- [Network Architecture](docs/en/network-architecture.md)
- [Deployment Guide](docs/en/deployment-guide.md)
- [Athena Query Templates](docs/en/athena-queries.md)
- [References](docs/en/references.md)
