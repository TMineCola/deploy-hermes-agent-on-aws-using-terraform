# S3 Bucket for Athena query results
resource "aws_s3_bucket" "athena_results" {
  count         = var.enable_vpc_flow_logs ? 1 : 0
  bucket        = "${var.project_name}-athena-results-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = { Name = "${var.project_name}-athena-results" }
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  count  = var.enable_vpc_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.athena_results[0].id

  rule {
    id     = "expire-query-results"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

# Athena Workgroup
resource "aws_athena_workgroup" "main" {
  count         = var.enable_vpc_flow_logs ? 1 : 0
  name          = var.project_name
  force_destroy = true

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results[0].bucket}/results/"
    }
  }

  tags = { Name = "${var.project_name}-athena" }
}

# Glue Catalog Database
resource "aws_glue_catalog_database" "main" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  name = replace(var.project_name, "-", "_")
}

# Glue Catalog Table for VPC Flow Logs (v3 schema)
resource "aws_glue_catalog_table" "vpc_flow_logs" {
  count         = var.enable_vpc_flow_logs ? 1 : 0
  name          = "vpc_flow_logs"
  database_name = aws_glue_catalog_database.main[0].name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "skip.header.line.count" = "1"
    "EXTERNAL"               = "TRUE"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.flow_logs[0].bucket}/AWSLogs/${data.aws_caller_identity.current.account_id}/vpcflowlogs/${var.aws_region}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "serialization.format" = " "
        "field.delim"          = " "
      }
    }

    columns {
      name = "version"
      type = "int"
    }
    columns {
      name = "account_id"
      type = "string"
    }
    columns {
      name = "interface_id"
      type = "string"
    }
    columns {
      name = "srcaddr"
      type = "string"
    }
    columns {
      name = "dstaddr"
      type = "string"
    }
    columns {
      name = "srcport"
      type = "int"
    }
    columns {
      name = "dstport"
      type = "int"
    }
    columns {
      name = "protocol"
      type = "bigint"
    }
    columns {
      name = "packets"
      type = "bigint"
    }
    columns {
      name = "bytes"
      type = "bigint"
    }
    columns {
      name = "start"
      type = "bigint"
    }
    columns {
      name = "end"
      type = "bigint"
    }
    columns {
      name = "action"
      type = "string"
    }
    columns {
      name = "log_status"
      type = "string"
    }
    columns {
      name = "vpc_id"
      type = "string"
    }
    columns {
      name = "subnet_id"
      type = "string"
    }
    columns {
      name = "instance_id"
      type = "string"
    }
    columns {
      name = "tcp_flags"
      type = "int"
    }
    columns {
      name = "type"
      type = "string"
    }
    columns {
      name = "pkt_srcaddr"
      type = "string"
    }
    columns {
      name = "pkt_dstaddr"
      type = "string"
    }
    columns {
      name = "region"
      type = "string"
    }
    columns {
      name = "az_id"
      type = "string"
    }
    columns {
      name = "sublocation_type"
      type = "string"
    }
    columns {
      name = "sublocation_id"
      type = "string"
    }
    columns {
      name = "pkt_src_aws_service"
      type = "string"
    }
    columns {
      name = "pkt_dst_aws_service"
      type = "string"
    }
    columns {
      name = "flow_direction"
      type = "string"
    }
    columns {
      name = "traffic_path"
      type = "int"
    }
  }
}
