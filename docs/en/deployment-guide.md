# Hermes Agent Deployment Guide

## Prerequisites

### Local Environment

| Tool | Minimum Version | Tested Version | Purpose |
|------|----------------|----------------|---------|
| Terraform | ~> 1.5 | v1.15.4 (darwin_arm64) | Infrastructure deployment |
| AWS CLI | >= 2.x | 2.29.1 (Python 3.13.7, arm64) | AWS authentication and operations |
| Git | >= 2.x | 2.51.0 | Version control |

### AWS Account Preparation

1. **IAM Permissions** — The IAM User/Role executing Terraform requires the following permissions:

| Service | Required Permissions | Purpose |
|---------|---------------------|---------|
| EC2 | `ec2:*` (VPC, Subnet, SG, Instance, EIP, NAT GW, Route Table, VPC Endpoint) | Create all networking and compute resources |
| IAM | `iam:CreateRole`, `iam:PutRolePolicy`, `iam:AttachRolePolicy`, `iam:CreateInstanceProfile`, `iam:AddRoleToInstanceProfile`, `iam:PassRole`, `iam:GetRole`, `iam:GetRolePolicy`, `iam:ListAttachedRolePolicies`, `iam:DeleteRole`, `iam:DeleteRolePolicy`, `iam:DetachRolePolicy`, `iam:RemoveRoleFromInstanceProfile`, `iam:DeleteInstanceProfile` | Create EC2 Instance Role and Flow Log Role |
| SSM | `ssm:GetParameter` | Read AMI ID (SSM Public Parameter) |
| CloudWatch Logs | `logs:CreateLogGroup`, `logs:DeleteLogGroup`, `logs:DescribeLogGroups`, `logs:PutRetentionPolicy`, `logs:TagResource` | VPC Flow Logs and CloudWatch Agent logs |
| S3 | `s3:CreateBucket`, `s3:PutBucketPolicy`, `s3:PutLifecycleConfiguration`, `s3:DeleteBucket`, `s3:GetBucketPolicy` | Flow Logs and Athena results storage |
| Glue | `glue:CreateDatabase`, `glue:DeleteDatabase`, `glue:CreateTable`, `glue:DeleteTable`, `glue:GetDatabase`, `glue:GetTable` | Athena data catalog |
| Athena | `athena:CreateWorkGroup`, `athena:DeleteWorkGroup`, `athena:GetWorkGroup` | Athena query workgroup |
| STS | `sts:GetCallerIdentity` | Terraform provider authentication |

2. **Complete the Anthropic FTU Form** (see Step 2)
3. **Create an S3 Bucket for Terraform State** (optional, for remote state management)

## Deployment Steps

### Step 1: Set Up Telegram Bot

1. Create a new Bot via [@BotFather](https://t.me/BotFather)
2. Obtain the Bot Token
3. (Optional) Get your Telegram User ID — send any message to [@userinfobot](https://t.me/userinfobot)
4. Enter the Token and User ID in `terraform.tfvars`:

```hcl
telegram_bot_token     = "YOUR_BOT_TOKEN"
telegram_allowed_users = "123456789"  # optional
```

> **About `telegram_allowed_users`** (optional):
> - When set, only the specified User IDs can use the Bot
> - Multiple users separated by commas: `"123456789,987654321"`
> - If not set, Hermes will generate a pairing code on first use; you need to connect via SSM and run `hermes approve <code>` to complete pairing
>
> 📖 Official docs: [Telegram Messaging](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/telegram)
> 📖 Environment variables: [Environment Variables](https://hermes-agent.nousresearch.com/docs/reference/environment-variables/)

### Step 2: Complete the Anthropic First Time Use (FTU) Form

Bedrock models are automatically enabled by default and do not require manual Model Access activation. However, **Anthropic models require a one-time FTU form submission before first use**:

1. Log in to AWS Console → Amazon Bedrock → Model catalog → Select any Anthropic model
2. Submit the First Time Use form (describe your use case and website URL)
3. After submission, all accounts under the Organization are automatically enabled; no approval wait required
4. Can also be submitted via API: `PutUseCaseForModelAccess`

> 📖 Official docs: [Request access to models](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html)

### Step 3: Initialize Terraform

```bash
cd terraform/
terraform init
```

### Step 4: Review Deployment Plan

```bash
terraform plan -var-file="terraform.tfvars"
```

### Step 5: Execute Deployment

```bash
terraform apply -var-file="terraform.tfvars"
```

Deployment order (automatically handled by Terraform dependency graph):
1. VPC + Subnets + Route Tables
2. Internet Gateway + NAT Gateway
3. Security Groups
4. VPC Endpoints (Bedrock, SSM, SSM Messages, EC2 Messages)
5. IAM Role + Instance Profile
6. EC2 Instance (with User Data startup script)

### Step 6: Verify Deployment

```bash
# Confirm EC2 instance is running
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=hermes-agent" \
  --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name}" \
  --region ap-northeast-1

# Connect via SSM Session Manager
aws ssm start-session \
  --target <instance-id> \
  --region ap-northeast-1
```

## Destroy Environment

```bash
terraform destroy -var-file="terraform.tfvars"
```

## Cost Analysis

Based on ap-northeast-1 (Tokyo) region, running 24/7.

### Official Pricing Documentation

| Service | Pricing Page |
|---------|-------------|
| EC2 On-Demand | https://aws.amazon.com/ec2/pricing/on-demand/ |
| EBS | https://aws.amazon.com/ebs/pricing/ |
| VPC (NAT Gateway) | https://aws.amazon.com/vpc/pricing/ |
| AWS PrivateLink (VPC Endpoint) | https://aws.amazon.com/privatelink/pricing/ |
| Bedrock | https://aws.amazon.com/bedrock/pricing/ |
| Public IPv4 Address | https://aws.amazon.com/vpc/pricing/ (Public IPv4 Address section) |
| Data Transfer | https://aws.amazon.com/ec2/pricing/on-demand/ (Data Transfer section) |

### Infrastructure Fixed Costs

| Resource | Specification | Unit Price (ap-northeast-1) | Monthly Cost (USD) |
|----------|--------------|----------------------------|-------------------|
| EC2 Instance | t4g.xlarge (4 vCPU, 16 GiB) | $0.1728/hr | $126.14 |
| EBS Volume | gp3, 100 GB | $0.096/GB/month | $9.60 |
| NAT Gateway | Fixed fee | $0.062/hr | $45.26 |
| VPC Endpoint (bedrock-runtime) | 1 AZ | $0.014/hr/AZ | $10.22 |
| VPC Endpoint (ssm) | 1 AZ | $0.014/hr/AZ | $10.22 |
| VPC Endpoint (ssmmessages) | 1 AZ | $0.014/hr/AZ | $10.22 |
| VPC Endpoint (ec2messages) | 1 AZ | $0.014/hr/AZ | $10.22 |
| Public IPv4 (NAT GW EIP) | 1 | $0.005/hr | $3.65 |
| SSM (Parameter Store + Session Manager) | Standard tier | Free | $0 |
| **Fixed Cost Subtotal** | | | **$225.53** |

### Variable Cost Pricing

| Item | Unit Price (ap-northeast-1) |
|------|----------------------------|
| NAT Gateway Data Processing | $0.062/GB |
| EC2 Data Transfer Out to Internet | First 100 GB/month free, then $0.114/GB |
| VPC Endpoint Data Processing | $0.01/GB |
| Bedrock Claude Opus 4.6 Input tokens | $5.00 / 1M tokens |
| Bedrock Claude Opus 4.6 Output tokens | $25.00 / 1M tokens |

### Monthly Estimated Total Cost

| Item | Monthly Cost (USD) |
|------|-------------------|
| Infrastructure fixed costs | $225.53 |
| + NAT Gateway / VPC Endpoint Data Processing | Depends on traffic |
| + EC2 Data Transfer Out | Depends on traffic |
| + Bedrock token usage | Depends on usage |

### Cost Optimization Suggestions

| Option | Savings | Description |
|--------|---------|-------------|
| Remove SSM-related VPC Endpoints (3) | -$30.66/month | Route SSM traffic via NAT Gateway instead |
| EC2 1-Year Savings Plan | ~-30% EC2 | Saves approximately $37/month |
| Use Sonnet 4.6 instead of Opus 4.6 | ~-80% Bedrock | Input $3/1M, Output $15/1M |

### Cost Tracking

All resources are automatically tagged via Terraform `default_tags`:

| Tag | Value | Purpose |
|-----|-------|---------|
| `Project` | hermes-agent | Filter by project in Cost Explorer |
| `Environment` | production | Distinguish environments |
| `ManagedBy` | terraform | Identify management method |

Enable Cost Allocation Tags (one-time action in Billing Console):
1. AWS Console → Billing → Cost Allocation Tags
2. Enable `Project` and `Environment` as cost allocation tags
3. Available in Cost Explorer for tag-based filtering after 24 hours

## Logging and Analytics Costs

The following are additional observability costs, not included in the infrastructure fixed cost calculation.

| Item | Billing Method | Unit Price (ap-northeast-1) |
|------|---------------|----------------------------|
| VPC Flow Logs (VendedLog → S3 ingestion) | Per GB written | $0.38/GB (first 10TB) |
| VPC Flow Logs S3 storage | S3 Standard | $0.025/GB/month |
| VPC Flow Logs S3 PUT Requests | Per 1,000 requests | $0.0047 |
| CloudWatch Agent custom metrics | Per metric/month | $0.30/metric (first 10,000) |
| Athena queries | Per TB scanned | $5.00/TB (minimum 10MB/query) |

> 💡 These are additional observability costs, not part of the infrastructure fixed costs. Actual charges depend on traffic volume and query frequency.
>
> Estimated reference:
> - CloudWatch Agent 4 custom metrics: ~$1.20/month
> - VPC Flow Logs (assuming 1GB/month traffic): ~$0.38 ingestion + $0.025 storage
> - Athena occasional queries (each scanning ~10MB): negligible

## Terraform Variable Configuration

`terraform.tfvars` example:

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

### Configurable Variables

> ⚠️ Before changing `aws_region`, `instance_type`, or `bedrock_model_id`, verify availability in the target region:
>
> ```bash
> # Verify EC2 instance type is available in the target region
> aws ec2 describe-instance-type-offerings \
>   --location-type region \
>   --filters "Name=instance-type,Values=t4g.xlarge" \
>   --region ap-northeast-1 \
>   --query "InstanceTypeOfferings[].InstanceType"
>
> # Verify Bedrock model is available in the target region
> aws bedrock list-inference-profiles \
>   --region ap-northeast-1 \
>   --query "inferenceProfileSummaries[?contains(inferenceProfileId,'claude-opus-4-6')].{Id:inferenceProfileId,Status:status}"
>
> # Verify VPC Endpoint service is available in the target region
> aws ec2 describe-vpc-endpoint-services \
>   --service-names com.amazonaws.ap-northeast-1.bedrock-runtime \
>   --region ap-northeast-1 \
>   --query "ServiceDetails[].ServiceName"
> ```

| Variable | Default Value | Description |
|----------|--------------|-------------|
| `project_name` | `hermes-agent` | Resource naming prefix; affects all resource Name tags and S3 bucket names |
| `environment` | `production` | Environment tag, used for Cost Explorer filtering |
| `aws_region` | `ap-northeast-1` | Deployment region; affects all resources and SSM/Bedrock settings in User Data |
| `instance_type` | `t4g.xlarge` | EC2 instance type |
| `ebs_volume_size` | `100` | EBS root volume size (GB) |
| `bedrock_model_id` | `global.anthropic.claude-opus-4-6-v1` | Bedrock model ID, injected into Hermes config.yaml |
| `telegram_bot_token` | (required) | Telegram Bot Token, stored in SSM SecureString |
| `telegram_allowed_users` | `""` (empty) | Allowed Telegram User IDs, comma-separated |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR range (must be /16; subnets are hardcoded as x.x.1.0/24 and x.x.2.0/24) |
| `enable_vpc_flow_logs` | `true` | Enable VPC Flow Logs to S3 + Athena |
| `enable_cloudwatch_agent` | `true` | Enable CloudWatch Agent for system metrics |
| `enable_vpc_endpoints` | `true` | Enable VPC Endpoints (PrivateLink); when disabled, Bedrock/SSM traffic routes via NAT Gateway |
| `tags` | `{}` | Custom tags, merged into all resource default_tags |

### Non-Extracted Hardcoded Values

The following values are written directly in Terraform files and change very infrequently:

| Value | Location | Description |
|-------|----------|-------------|
| `10.0.1.0/24` / `10.0.2.0/24` | vpc.tf | Subnet CIDRs, derived from VPC CIDR |
| `30` / `90` (days) | monitoring.tf | Flow Logs S3 lifecycle (30 days transition to IA, 90 days deletion) |
| `30` (days) | athena.tf | Athena query results retention period |
| `443` | security_groups.tf | VPC Endpoint inbound port |

## Monitoring and Alarms

### CloudWatch Agent Monitoring Metrics

User Data automatically installs and configures the CloudWatch Agent, collecting the following metrics:

| Metric | Namespace | Description |
|--------|-----------|-------------|
| `cpu_usage_active` | HermesAgent | Overall CPU utilization |
| `mem_used_percent` | HermesAgent | Memory utilization |
| `disk_used_percent` (path: `/`) | HermesAgent | Root disk utilization |
| `swap_used_percent` | HermesAgent | Swap utilization |

### Recommended Alarms

Uses M out of N evaluation mode to avoid false alarms caused by back-filled data.

> 📖 Official docs: [Recommended alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html)

| Monitor Item | Statistic | Threshold | Period | Datapoints to Alarm | Evaluation Periods | Description |
|-------------|-----------|-----------|--------|--------------------|--------------------|-------------|
| CPU utilization | Average | > 80% | 300s | 2 | 3 | 2 out of 3 (2 breaches within 15 minutes) |
| Memory utilization | Average | > 85% | 300s | 2 | 3 | 2 out of 3 |
| Disk utilization | Average | > 80% | 300s | 2 | 3 | 2 out of 3 |
| EC2 StatusCheck | Maximum | >= 1 | 300s | 2 | 2 | Officially recommended 2 out of 2 |
