resource "aws_ssm_parameter" "telegram_bot_token" {
  name  = "/${var.project_name}/telegram-bot-token"
  type  = "SecureString"
  value = var.telegram_bot_token

  tags = { Name = "${var.project_name}-telegram-bot-token" }
}

resource "aws_ssm_parameter" "telegram_allowed_users" {
  count = var.telegram_allowed_users != "" ? 1 : 0
  name  = "/${var.project_name}/telegram-allowed-users"
  type  = "String"
  value = var.telegram_allowed_users

  tags = { Name = "${var.project_name}-telegram-allowed-users" }
}
