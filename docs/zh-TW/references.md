# 參考資料與引述

本文件記錄所有研究過程中引用的官方文件、部落格文章與可信資源。

## AWS 官方文件

### Amazon Bedrock

| 資源 | 連結 | 重點摘要 |
|------|------|----------|
| Claude Opus 4.6 Model Card | [docs.aws.amazon.com](https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-anthropic-claude-opus-4-6.html) | Model ID: `anthropic.claude-opus-4-6-v1`，1M context window，128K max output，ap-northeast-1 僅支援 Global Cross-Region Inference (`global.anthropic.claude-opus-4-6-v1`) |
| Bedrock VPC Interface Endpoints | [docs.aws.amazon.com](https://docs.aws.amazon.com/bedrock/latest/userguide/vpc-interface-endpoints.html) | 服務名稱 `com.amazonaws.{region}.bedrock-runtime`，支援 Private DNS，可附加 Endpoint Policy 限制 API 操作 |
| Bedrock Security & Compliance | [aws.amazon.com](https://aws.amazon.com/bedrock/security-compliance/) | 支援 PrivateLink、KMS 加密、CloudTrail 審計、符合 ISO/SOC/HIPAA/GDPR |
| Bedrock Model Access (自動啟用) | [docs.aws.amazon.com](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html) | 2025/10 起模型預設自動啟用，Anthropic 模型仍需一次性 FTU 表單 |
| Bedrock 自動啟用公告 | [aws.amazon.com](https://aws.amazon.com/about-aws/whats-new/2025/10/amazon-bedrock-automatic-enablement-serverless-foundation-models/) | 所有 serverless 模型預設啟用，可透過 IAM/SCP 控制存取 |
| Cross-Region Inference (Japan) | [aws.amazon.com/blogs](https://aws.amazon.com/blogs/machine-learning/introducing-amazon-bedrock-cross-region-inference-for-claude-sonnet-4-5-and-haiku-4-5-in-japan-and-australia/) | CRIS 在日本可用，路由於 Tokyo 和 Osaka 之間，資料保留在地理區域內 |
| PrivateLink Setup Blog | [aws.amazon.com/blogs](https://aws.amazon.com/blogs/machine-learning/use-aws-privatelink-to-set-up-private-access-to-amazon-bedrock/) | 完整架構範例：VPC 內 Lambda/EC2 透過 PrivateLink 存取 Bedrock，含 Endpoint Policy 範例 |

### Amazon EC2 & IAM

| 資源 | 連結 | 重點摘要 |
|------|------|----------|
| IAM Roles for EC2 | [docs.aws.amazon.com](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html) | 使用 Instance Profile 提供臨時憑證，遵循最小權限原則，每個實例只能附加一個 Role |
| EC2 Instance Role Best Practices | [docs.aws.amazon.com](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2.html) | 透過 Instance Profile 自動輪換臨時憑證，無需手動管理 Access Key |
| Safer Credential Distribution | [aws.amazon.com/blogs](https://aws.amazon.com/blogs/security/a-safer-way-to-distribute-aws-credentials-to-ec2/) | 使用 IAM Role 取代硬編碼 Access Key，含建立 Role 和移除舊憑證的步驟 |
| PassRole Permission | [aws.amazon.com/blogs](https://aws.amazon.com/blogs/security/granting-permission-to-launch-ec2-instances-with-iam-roles-passrole-permission/) | 啟動帶 Role 的 EC2 需要 `iam:PassRole` 權限，防止權限提升攻擊 |

### Amazon Linux 2023

| 資源 | 連結 | 重點摘要 |
|------|------|----------|
| AL2023 on EC2 | [docs.aws.amazon.com](https://docs.aws.amazon.com/linux/al2023/ug/ec2.html) | SSM Parameter 路徑: `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64` (ARM64/Graviton)，AMI 每 90 天 deprecate |

### VPC & Networking

| 資源 | 連結 | 重點摘要 |
|------|------|----------|
| AWS PrivateLink Guide | [docs.aws.amazon.com](https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-aws-services.html) | Interface Endpoint 建立私有連線，每個子網建立 ENI，支援 Private DNS |
| Create Interface Endpoint | [docs.aws.amazon.com](https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html) | 建立步驟與注意事項 |
| Endpoint Policies | [docs.aws.amazon.com](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-access.html) | 可限制透過 Endpoint 存取的 API 操作和資源 |

## Terraform 相關

| 資源 | 連結 | 重點摘要 |
|------|------|----------|
| AWS Provider | [registry.terraform.io](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) | 使用 `~> 5.0` 版本，支援所有本方案使用的資源類型 |
| aws_vpc_endpoint | [registry.terraform.io](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | Interface type endpoint 設定，含 private_dns_enabled 參數 |
| aws_instance | [registry.terraform.io](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | metadata_options 設定 IMDSv2，user_data 支援 templatefile |
| aws_ssm_parameter (data) | [registry.terraform.io](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | 用於動態取得最新 AMI ID |

## 安全設計決策依據

| 決策 | 依據 |
|------|------|
| EC2 零 Inbound | Telegram Bot 使用 Long Polling (Outbound HTTPS)，無需接收外部連線 |
| IMDSv2 強制 | 防止 SSRF 攻擊竊取 Instance Metadata 中的臨時憑證 ([AWS 建議](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)) |
| EBS 加密 | 保護靜態資料，使用 AWS managed key ([AWS 建議](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSEncryption.html)) |
| SSM Session Manager 取代 SSH | 無需開放 Port 22，所有操作有 CloudTrail 審計記錄 ([AWS 文件](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)) |
| VPC Flow Logs | 記錄所有網路流量供安全審計 ([AWS 文件](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)) |
| PrivateLink for Bedrock | Bedrock API 呼叫不經過公網，減少資料外洩風險 |
| 最小權限 IAM Policy | 僅授予 `bedrock:InvokeModel` 和 `ssm:GetParameter`，限定資源 ARN |

## 架構決策記錄 (ADR)

### ADR-001: Claude Opus 4.6 存取方式

**背景**: Claude Opus 4.6 在 ap-northeast-1 不支援 In-Region 推論。

**決策**: 使用 Global Cross-Region Inference (`global.anthropic.claude-opus-4-6-v1`)。

**影響**:
- 請求可能路由到其他區域 (如 us-east-1, us-west-2)
- 延遲可能略高於 In-Region
- 資料可能離開日本地理區域 (Global 模式無地理限制)
- 如有資料駐留需求，需等待 In-Region 或 Geo (JP) 支援

### ADR-002: 單一 AZ 部署

**背景**: 個人助理專案，不需要企業級高可用。

**決策**: 僅部署在 ap-northeast-1a 單一 AZ。

**影響**:
- 節省 NAT Gateway 和 VPC Endpoint 的多 AZ 費用
- AZ 故障時服務中斷
- 未來可擴展為多 AZ

### ADR-003: Telegram Long Polling vs Webhook

**背景**: Telegram Bot 支援 Polling 和 Webhook 兩種模式。

**決策**: 使用 Long Polling。

**影響**:
- 無需公網 IP、Load Balancer 或 SSL 憑證
- 安全性更高 (零 Inbound)
- 回應延遲略高於 Webhook (通常 < 1 秒)
- 適合個人使用場景

## 研究日期

所有資料查閱於 2026 年 5 月 26 日。AWS 服務可用性和定價可能隨時變動，部署前請確認最新資訊。
