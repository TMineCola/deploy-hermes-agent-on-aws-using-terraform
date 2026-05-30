# Hermes Agent 部署流程

## 前置條件

### 本地環境

| 工具 | 最低版本 | 測試環境版本 | 用途 |
|------|----------|-------------|------|
| Terraform | ~> 1.5 | v1.15.4 (darwin_arm64) | 基礎設施部署 |
| AWS CLI | >= 2.x | 2.29.1 (Python 3.13.7, arm64) | AWS 認證與操作 |
| Git | >= 2.x | 2.51.0 | 版本控制 |

### AWS 帳號準備

1. **IAM 權限** — 執行 Terraform 的 IAM User/Role 需要以下權限：

| 服務 | 所需權限 | 用途 |
|------|----------|------|
| EC2 | `ec2:*` (VPC, Subnet, SG, Instance, EIP, NAT GW, Route Table, VPC Endpoint) | 建立所有網路和運算資源 |
| IAM | `iam:CreateRole`, `iam:PutRolePolicy`, `iam:AttachRolePolicy`, `iam:CreateInstanceProfile`, `iam:AddRoleToInstanceProfile`, `iam:PassRole`, `iam:GetRole`, `iam:GetRolePolicy`, `iam:ListAttachedRolePolicies`, `iam:DeleteRole`, `iam:DeleteRolePolicy`, `iam:DetachRolePolicy`, `iam:RemoveRoleFromInstanceProfile`, `iam:DeleteInstanceProfile` | 建立 EC2 Instance Role 和 Flow Log Role |
| SSM | `ssm:GetParameter` | 讀取 AMI ID (SSM Public Parameter) |
| CloudWatch Logs | `logs:CreateLogGroup`, `logs:DeleteLogGroup`, `logs:DescribeLogGroups`, `logs:PutRetentionPolicy`, `logs:TagResource` | VPC Flow Logs 和 CloudWatch Agent 日誌 |
| S3 | `s3:CreateBucket`, `s3:PutBucketPolicy`, `s3:PutLifecycleConfiguration`, `s3:DeleteBucket`, `s3:GetBucketPolicy` | Flow Logs 和 Athena 結果儲存 |
| Glue | `glue:CreateDatabase`, `glue:DeleteDatabase`, `glue:CreateTable`, `glue:DeleteTable`, `glue:GetDatabase`, `glue:GetTable` | Athena 資料目錄 |
| Athena | `athena:CreateWorkGroup`, `athena:DeleteWorkGroup`, `athena:GetWorkGroup` | Athena 查詢工作區 |
| STS | `sts:GetCallerIdentity` | Terraform provider 驗證 |

2. **完成 Anthropic FTU 表單** (見 Step 2)
3. **建立 Terraform State 用的 S3 Bucket** (可選，用於遠端狀態管理)

## 部署步驟

### Step 1: 設定 Telegram Bot

1. 透過 [@BotFather](https://t.me/BotFather) 建立新 Bot
2. 取得 Bot Token
3. (Optional) 取得你的 Telegram User ID — 向 [@userinfobot](https://t.me/userinfobot) 發送任意訊息即可取得
4. 將 Token 和 User ID 填入 `terraform.tfvars`：

```hcl
telegram_bot_token     = "YOUR_BOT_TOKEN"
telegram_allowed_users = "123456789"  # optional
```

> **關於 `telegram_allowed_users`** (optional):
> - 設定後，只有指定的 User ID 可以使用 Bot
> - 多個用戶以逗號分隔: `"123456789,987654321"`
> - 若不設定，首次使用時 Hermes 會產生 pairing code，需透過 SSM 連線到機器執行 `hermes approve <code>` 完成配對
>
> 📖 官方文件: [Telegram Messaging](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/telegram)
> 📖 環境變數: [Environment Variables](https://hermes-agent.nousresearch.com/docs/reference/environment-variables/)

### Step 2: 完成 Anthropic First Time Use (FTU) 表單

Bedrock 模型預設已自動啟用，無需手動開啟 Model Access。但 **Anthropic 模型首次使用前需提交一次性 FTU 表單**：

1. 登入 AWS Console → Amazon Bedrock → Model catalog → 選擇任一 Anthropic 模型
2. 提交 First Time Use 表單 (描述使用案例和網站 URL)
3. 提交後整個 Organization 下所有帳號自動啟用，無需等待核准
4. 也可透過 API 提交：`PutUseCaseForModelAccess`

> 📖 官方文件: [Request access to models](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html)

### Step 3: 初始化 Terraform

```bash
cd terraform/
terraform init
```

### Step 4: 檢視部署計畫

```bash
terraform plan -var-file="terraform.tfvars"
```

### Step 5: 執行部署

```bash
terraform apply -var-file="terraform.tfvars"
```

部署順序 (由 Terraform 依賴關係自動處理)：
1. VPC + Subnets + Route Tables
2. Internet Gateway + NAT Gateway
3. Security Groups
4. VPC Endpoints (Bedrock, SSM, SSM Messages, EC2 Messages)
5. IAM Role + Instance Profile
6. EC2 Instance (含 User Data 啟動腳本)

### Step 6: 驗證部署

```bash
# 確認 EC2 實例運行中
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=hermes-agent" \
  --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name}" \
  --region ap-northeast-1

# 透過 SSM Session Manager 連線
aws ssm start-session \
  --target <instance-id> \
  --region ap-northeast-1
```

## 銷毀環境

```bash
terraform destroy -var-file="terraform.tfvars"
```

## 成本分析

以 ap-northeast-1 (Tokyo) 區域、24/7 運行為基準。

### 官方定價文件

| 服務 | 定價頁面 |
|------|----------|
| EC2 On-Demand | https://aws.amazon.com/ec2/pricing/on-demand/ |
| EBS | https://aws.amazon.com/ebs/pricing/ |
| VPC (NAT Gateway) | https://aws.amazon.com/vpc/pricing/ |
| AWS PrivateLink (VPC Endpoint) | https://aws.amazon.com/privatelink/pricing/ |
| Bedrock | https://aws.amazon.com/bedrock/pricing/ |
| Public IPv4 Address | https://aws.amazon.com/vpc/pricing/ (Public IPv4 Address 區段) |
| Data Transfer | https://aws.amazon.com/ec2/pricing/on-demand/ (Data Transfer 區段) |

### 基礎設施固定成本

| 資源 | 規格 | 單價 (ap-northeast-1) | 月費 (USD) |
|------|------|----------------------|-----------|
| EC2 Instance | t4g.xlarge (4 vCPU, 16 GiB) | $0.1728/hr | $126.14 |
| EBS Volume | gp3, 100 GB | $0.096/GB/月 | $9.60 |
| NAT Gateway | 固定費用 | $0.062/hr | $45.26 |
| VPC Endpoint (bedrock-runtime) | 1 AZ | $0.014/hr/AZ | $10.22 |
| VPC Endpoint (ssm) | 1 AZ | $0.014/hr/AZ | $10.22 |
| VPC Endpoint (ssmmessages) | 1 AZ | $0.014/hr/AZ | $10.22 |
| VPC Endpoint (ec2messages) | 1 AZ | $0.014/hr/AZ | $10.22 |
| Public IPv4 (NAT GW EIP) | 1 個 | $0.005/hr | $3.65 |
| SSM (Parameter Store + Session Manager) | Standard tier | 免費 | $0 |
| **固定成本小計** | | | **$225.53** |

### 變動成本定價

| 項目 | 單價 (ap-northeast-1) |
|------|----------------------|
| NAT Gateway Data Processing | $0.062/GB |
| EC2 Data Transfer Out to Internet | 前 100 GB/月免費，之後 $0.114/GB |
| VPC Endpoint Data Processing | $0.01/GB |
| Bedrock Claude Opus 4.6 Input tokens | $5.00 / 1M tokens |
| Bedrock Claude Opus 4.6 Output tokens | $25.00 / 1M tokens |

### 每月預測總成本

| 項目 | 月費 (USD) |
|------|-----------|
| 基礎設施固定成本 | $225.53 |
| + NAT Gateway / VPC Endpoint Data Processing | 依流量 |
| + EC2 Data Transfer Out | 依流量 |
| + Bedrock Token 使用量 | 依使用量 |

### 成本優化建議

| 方案 | 節省 | 說明 |
|------|------|------|
| 移除 SSM 相關 VPC Endpoints (3 個) | -$30.66/月 | 改走 NAT Gateway 路由 SSM 流量 |
| EC2 1-Year Savings Plan | -~30% EC2 | 約省 $37/月 |
| 使用 Sonnet 4.6 替代 Opus 4.6 | -~80% Bedrock | Input $3/1M, Output $15/1M |

### 成本追蹤

所有資源透過 Terraform `default_tags` 自動標記：

| Tag | 值 | 用途 |
|-----|------|------|
| `Project` | hermes-agent | Cost Explorer 按專案篩選 |
| `Environment` | production | 區分環境 |
| `ManagedBy` | terraform | 識別管理方式 |

啟用 Cost Allocation Tags (需在 Billing Console 操作一次)：
1. AWS Console → Billing → Cost Allocation Tags
2. 啟用 `Project`、`Environment` 為 cost allocation tags
3. 24 小時後即可在 Cost Explorer 中按 tag 篩選

## 日誌與分析成本

以下為觀測相關的額外成本，不納入基礎設施固定成本計算。

| 項目 | 計費方式 | 單價 (ap-northeast-1) |
|------|----------|----------------------|
| VPC Flow Logs (VendedLog → S3 ingestion) | 每 GB 寫入 | $0.38/GB (前 10TB) |
| VPC Flow Logs S3 儲存 | S3 Standard | $0.025/GB/月 |
| VPC Flow Logs S3 PUT Requests | 每 1,000 requests | $0.0047 |
| CloudWatch Agent custom metrics | 每個指標/月 | $0.30/metric (前 10,000) |
| Athena 查詢 | 每 TB 掃描 | $5.00/TB (最低 10MB/query) |

> 💡 這些是額外的觀測成本，不屬於基礎設施固定成本。實際費用取決於流量大小和查詢頻率。
>
> 預估參考：
> - CloudWatch Agent 4 個 custom metrics: ~$1.20/月
> - VPC Flow Logs (假設 1GB/月流量): ~$0.38 ingestion + $0.025 storage
> - Athena 偶爾查詢 (每次掃描 ~10MB): 幾乎可忽略

## Terraform 變數配置

`terraform.tfvars` 範例：

```hcl
project_name           = "hermes-agent"
environment            = "production"
aws_region             = "ap-northeast-1"
instance_type          = "t4g.xlarge"
ebs_volume_size        = 100
bedrock_model_id       = "global.anthropic.claude-opus-4-6-v1"
telegram_bot_token     = "YOUR_BOT_TOKEN"
telegram_allowed_users = "123456789"
```

### 可配置變數

> ⚠️ 變更 `aws_region`、`instance_type` 或 `bedrock_model_id` 前，請先確認目標區域的可用性：
>
> ```bash
> # 確認 EC2 instance type 在目標區域可用
> aws ec2 describe-instance-type-offerings \
>   --location-type region \
>   --filters "Name=instance-type,Values=t4g.xlarge" \
>   --region ap-northeast-1 \
>   --query "InstanceTypeOfferings[].InstanceType"
>
> # 確認 Bedrock 模型在目標區域可用
> aws bedrock list-inference-profiles \
>   --region ap-northeast-1 \
>   --query "inferenceProfileSummaries[?contains(inferenceProfileId,'claude-opus-4-6')].{Id:inferenceProfileId,Status:status}"
>
> # 確認 VPC Endpoint 服務在目標區域可用
> aws ec2 describe-vpc-endpoint-services \
>   --service-names com.amazonaws.ap-northeast-1.bedrock-runtime \
>   --region ap-northeast-1 \
>   --query "ServiceDetails[].ServiceName"
> ```

| 變數 | 預設值 | 說明 |
|------|--------|------|
| `project_name` | `hermes-agent` | 資源命名前綴，影響所有資源的 Name tag 和 S3 bucket 名稱 |
| `environment` | `production` | 環境標籤，用於 Cost Explorer 篩選 |
| `aws_region` | `ap-northeast-1` | 部署區域，影響所有資源和 User Data 中的 SSM/Bedrock 設定 |
| `instance_type` | `t4g.xlarge` | EC2 實例類型 |
| `ebs_volume_size` | `100` | EBS 根磁碟大小 (GB) |
| `bedrock_model_id` | `global.anthropic.claude-opus-4-6-v1` | Bedrock 模型 ID，注入到 Hermes config.yaml |
| `telegram_bot_token` | (必填) | Telegram Bot Token，存入 SSM SecureString |
| `telegram_allowed_users` | `""` (空) | 允許的 Telegram User ID，逗號分隔 |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR 範圍 (必須為 /16，Subnet 硬編碼為 x.x.1.0/24 和 x.x.2.0/24) |
| `enable_vpc_flow_logs` | `true` | 啟用 VPC Flow Logs → S3 + Athena |
| `enable_cloudwatch_agent` | `true` | 啟用 CloudWatch Agent 系統指標收集 |
| `enable_vpc_endpoints` | `true` | 啟用 VPC Endpoints (PrivateLink)，關閉後 Bedrock/SSM 流量走 NAT Gateway |
| `tags` | `{}` | 自定義 tags，會 merge 到所有資源的 default_tags |

### 未抽出的硬編碼值

以下值直接寫在 Terraform 文件中，變更頻率極低：

| 值 | 位置 | 說明 |
|----|------|------|
| `10.0.1.0/24` / `10.0.2.0/24` | vpc.tf | Subnet CIDR，從 VPC CIDR 衍生 |
| `30` / `90` (days) | monitoring.tf | Flow Logs S3 lifecycle (30 天轉 IA，90 天刪除) |
| `30` (days) | athena.tf | Athena 查詢結果保留天數 |
| `443` | security_groups.tf | VPC Endpoint 入站端口 |

## 監控與告警

### CloudWatch Agent 監控指標

User Data 已自動安裝並配置 CloudWatch Agent，收集以下指標：

| 指標 | Namespace | 說明 |
|------|-----------|------|
| `cpu_usage_active` | HermesAgent | 整體 CPU 使用率 |
| `mem_used_percent` | HermesAgent | 記憶體使用率 |
| `disk_used_percent` (path: `/`) | HermesAgent | 根磁碟使用率 |
| `swap_used_percent` | HermesAgent | Swap 使用率 |

### 建議告警

採用 M out of N 評估模式避免 back-filled data 造成誤報。

> 📖 官方文件: [Recommended alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html)

| 監控項目 | Statistic | 閾值 | Period | Datapoints to Alarm | Evaluation Periods | 說明 |
|----------|-----------|------|--------|--------------------|--------------------|------|
| CPU 使用率 | Average | > 80% | 300s | 2 | 3 | 2 out of 3 (15 分鐘內有 2 次超標) |
| 記憶體使用率 | Average | > 85% | 300s | 2 | 3 | 2 out of 3 |
| 磁碟使用率 | Average | > 80% | 300s | 2 | 3 | 2 out of 3 |
| EC2 StatusCheck | Maximum | >= 1 | 300s | 2 | 2 | 官方推薦 2 out of 2 |

