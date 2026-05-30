output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.hermes.id
}

output "ssm_connect_command" {
  description = "Command to connect via SSM Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.hermes.id} --region ${var.aws_region}"
}

output "flow_logs_bucket" {
  description = "S3 bucket for VPC Flow Logs"
  value       = var.enable_vpc_flow_logs ? aws_s3_bucket.flow_logs[0].bucket : null
}

output "athena_workgroup" {
  description = "Athena workgroup name"
  value       = var.enable_vpc_flow_logs ? aws_athena_workgroup.main[0].name : null
}

output "athena_database" {
  description = "Glue catalog database for Athena queries"
  value       = var.enable_vpc_flow_logs ? aws_glue_catalog_database.main[0].name : null
}

output "athena_results_bucket" {
  description = "S3 bucket for Athena query results"
  value       = var.enable_vpc_flow_logs ? aws_s3_bucket.athena_results[0].bucket : null
}
