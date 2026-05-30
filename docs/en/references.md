# References and Citations

This document records all official documentation, blog posts, and trusted resources referenced during the research process.

## AWS Official Documentation

### Amazon Bedrock

| Resource | Link | Key Takeaways |
|----------|------|---------------|
| Claude Opus 4.6 Model Card | [docs.aws.amazon.com](https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-anthropic-claude-opus-4-6.html) | Model ID: `anthropic.claude-opus-4-6-v1`, 1M context window, 128K max output, ap-northeast-1 supports Global Cross-Region Inference only (`global.anthropic.claude-opus-4-6-v1`) |
| Bedrock VPC Interface Endpoints | [docs.aws.amazon.com](https://docs.aws.amazon.com/bedrock/latest/userguide/vpc-interface-endpoints.html) | Service name `com.amazonaws.{region}.bedrock-runtime`, supports Private DNS, can attach Endpoint Policy to restrict API operations |
| Bedrock Security & Compliance | [aws.amazon.com](https://aws.amazon.com/bedrock/security-compliance/) | Supports PrivateLink, KMS encryption, CloudTrail auditing, ISO/SOC/HIPAA/GDPR compliant |
| Bedrock Model Access (Auto-Enabled) | [docs.aws.amazon.com](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html) | Since 2025/10, models are auto-enabled by default; Anthropic models still require a one-time FTU form |
| Bedrock Auto-Enablement Announcement | [aws.amazon.com](https://aws.amazon.com/about-aws/whats-new/2025/10/amazon-bedrock-automatic-enablement-serverless-foundation-models/) | All serverless models enabled by default, access controllable via IAM/SCP |
| Cross-Region Inference (Japan) | [aws.amazon.com/blogs](https://aws.amazon.com/blogs/machine-learning/introducing-amazon-bedrock-cross-region-inference-for-claude-sonnet-4-5-and-haiku-4-5-in-japan-and-australia/) | CRIS available in Japan, routes between Tokyo and Osaka, data stays within geographic region |
| PrivateLink Setup Blog | [aws.amazon.com/blogs](https://aws.amazon.com/blogs/machine-learning/use-aws-privatelink-to-set-up-private-access-to-amazon-bedrock/) | Complete architecture example: Lambda/EC2 in VPC accessing Bedrock via PrivateLink, includes Endpoint Policy examples |

### Amazon EC2 & IAM

| Resource | Link | Key Takeaways |
|----------|------|---------------|
| IAM Roles for EC2 | [docs.aws.amazon.com](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html) | Use Instance Profile to provide temporary credentials, follow least privilege principle, each instance can attach only one Role |
| EC2 Instance Role Best Practices | [docs.aws.amazon.com](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2.html) | Automatic rotation of temporary credentials via Instance Profile, no manual Access Key management needed |
| Safer Credential Distribution | [aws.amazon.com/blogs](https://aws.amazon.com/blogs/security/a-safer-way-to-distribute-aws-credentials-to-ec2/) | Use IAM Role instead of hardcoded Access Keys, includes steps for creating Role and removing old credentials |
| PassRole Permission | [aws.amazon.com/blogs](https://aws.amazon.com/blogs/security/granting-permission-to-launch-ec2-instances-with-iam-roles-passrole-permission/) | Launching EC2 with a Role requires `iam:PassRole` permission to prevent privilege escalation attacks |

### Amazon Linux 2023

| Resource | Link | Key Takeaways |
|----------|------|---------------|
| AL2023 on EC2 | [docs.aws.amazon.com](https://docs.aws.amazon.com/linux/al2023/ug/ec2.html) | SSM Parameter path: `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64` (ARM64/Graviton), AMI deprecated every 90 days |

### VPC & Networking

| Resource | Link | Key Takeaways |
|----------|------|---------------|
| AWS PrivateLink Guide | [docs.aws.amazon.com](https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-aws-services.html) | Interface Endpoint creates private connections, creates ENI in each subnet, supports Private DNS |
| Create Interface Endpoint | [docs.aws.amazon.com](https://docs.aws.amazon.com/vpc/latest/privatelink/create-interface-endpoint.html) | Creation steps and considerations |
| Endpoint Policies | [docs.aws.amazon.com](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-access.html) | Can restrict API operations and resources accessible through the Endpoint |

## Terraform

| Resource | Link | Key Takeaways |
|----------|------|---------------|
| AWS Provider | [registry.terraform.io](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) | Uses `~> 5.0` version, supports all resource types used in this project |
| aws_vpc_endpoint | [registry.terraform.io](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | Interface type endpoint configuration, includes private_dns_enabled parameter |
| aws_instance | [registry.terraform.io](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | metadata_options for IMDSv2 configuration, user_data supports templatefile |
| aws_ssm_parameter (data) | [registry.terraform.io](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | Used to dynamically retrieve the latest AMI ID |

## Security Design Decision Rationale

| Decision | Rationale |
|----------|-----------|
| EC2 Zero Inbound | Telegram Bot uses Long Polling (Outbound HTTPS), no need to receive external connections |
| IMDSv2 Enforced | Prevents SSRF attacks from stealing temporary credentials in Instance Metadata ([AWS recommendation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)) |
| EBS Encryption | Protects data at rest, uses AWS managed key ([AWS recommendation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSEncryption.html)) |
| SSM Session Manager Replaces SSH | No need to open Port 22, all operations have CloudTrail audit records ([AWS docs](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)) |
| VPC Flow Logs | Records all network traffic for security auditing ([AWS docs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)) |
| PrivateLink for Bedrock | Bedrock API calls do not traverse the public internet, reducing data exfiltration risk |
| Least Privilege IAM Policy | Grants only `bedrock:InvokeModel` and `ssm:GetParameter`, with restricted resource ARNs |

## Architecture Decision Records (ADR)

### ADR-001: Claude Opus 4.6 Access Method

**Context**: Claude Opus 4.6 does not support In-Region inference in ap-northeast-1.

**Decision**: Use Global Cross-Region Inference (`global.anthropic.claude-opus-4-6-v1`).

**Impact**:
- Requests may be routed to other regions (e.g., us-east-1, us-west-2)
- Latency may be slightly higher than In-Region
- Data may leave the Japan geographic region (Global mode has no geographic restrictions)
- If data residency is required, wait for In-Region or Geo (JP) support

### ADR-002: Single AZ Deployment

**Context**: A personal assistant project that does not require enterprise-grade high availability.

**Decision**: Deploy in ap-northeast-1a single AZ only.

**Impact**:
- Saves multi-AZ costs for NAT Gateway and VPC Endpoints
- Service interruption during AZ failure
- Can be expanded to multi-AZ in the future

### ADR-003: Telegram Long Polling vs Webhook

**Context**: Telegram Bot supports both Polling and Webhook modes.

**Decision**: Use Long Polling.

**Impact**:
- No public IP, Load Balancer, or SSL certificate required
- Higher security (zero inbound)
- Slightly higher response latency compared to Webhook (typically < 1 second)
- Suitable for personal use scenarios

## Research Date

All materials were reviewed on May 26, 2026. AWS service availability and pricing may change at any time; please verify the latest information before deployment.
