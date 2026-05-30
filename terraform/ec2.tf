# Latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_instance" "hermes" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids = [aws_security_group.ec2.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = var.ebs_volume_size
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    aws_region              = var.aws_region
    project_name            = var.project_name
    bedrock_model_id        = var.bedrock_model_id
    enable_cloudwatch_agent = var.enable_cloudwatch_agent
  }))

  tags = { Name = var.project_name }
}
