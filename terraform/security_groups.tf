# EC2 Security Group - Zero Inbound
resource "aws_security_group" "ec2" {
  name_prefix = "${var.project_name}-ec2-"
  description = "Hermes Agent EC2 - outbound only"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ec2-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

# VPC Endpoint Security Group
resource "aws_security_group" "vpce" {
  count       = var.enable_vpc_endpoints ? 1 : 0
  name_prefix = "${var.project_name}-vpce-"
  description = "VPC Endpoints - accept HTTPS from EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTPS from EC2"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = { Name = "${var.project_name}-vpce-sg" }

  lifecycle {
    create_before_destroy = true
  }
}
