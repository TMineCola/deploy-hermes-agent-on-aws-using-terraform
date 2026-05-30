# Bedrock Runtime VPC Endpoint
resource "aws_vpc_endpoint" "bedrock_runtime" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpce[0].id]

  tags = { Name = "${var.project_name}-vpce-bedrock-runtime" }
}

# SSM VPC Endpoint (Parameter Store + Session Manager)
resource "aws_vpc_endpoint" "ssm" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpce[0].id]

  tags = { Name = "${var.project_name}-vpce-ssm" }
}

# SSM Messages VPC Endpoint (Session Manager)
resource "aws_vpc_endpoint" "ssmmessages" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpce[0].id]

  tags = { Name = "${var.project_name}-vpce-ssmmessages" }
}

# EC2 Messages VPC Endpoint (SSM Agent)
resource "aws_vpc_endpoint" "ec2messages" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpce[0].id]

  tags = { Name = "${var.project_name}-vpce-ec2messages" }
}
