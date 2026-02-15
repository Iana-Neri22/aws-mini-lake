provider "aws" {
  region                      = "us-east-2"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3      = "http://localhost:4566"
    lambda  = "http://localhost:4566"
    iam     = "http://localhost:4566"
    glue    = "http://localhost:4566"
    athena  = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "raw" {
  bucket = "raw-transactions"
  force_destroy = true
}

resource "aws_s3_bucket" "curated" {
  bucket = "curated-transactions"
  force_destroy = true
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_lambda_function" "process_transactions" {
  function_name = "process-transactions"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.9"

  filename         = "../function.zip"
  source_code_hash = filebase64sha256("../function.zip")
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_transactions.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw.arn
}

resource "aws_s3_bucket_notification" "raw_notification" {
  bucket = aws_s3_bucket.raw.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_transactions.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_s3_bucket" "athena_results" {
  bucket        = "athena-query-results"
  force_destroy = true
}

resource "aws_glue_catalog_database" "analytics" {
  name = "mini_lake_db"
}

resource "aws_glue_catalog_table" "transactions" {
  name          = "transactions"
  database_name = aws_glue_catalog_database.analytics.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "csv"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.curated.bucket}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"

      parameters = {
        "field.delim" = ","
      }
    }

    columns {
      name = "transaction_id"
      type = "string"
    }

    columns {
      name = "customer_id"
      type = "string"
    }

    columns {
      name = "amount"
      type = "string"
    }

    columns {
      name = "processed_at"
      type = "string"
    }
  }

  partition_keys {
    name = "dt_reference"
    type = "string"
  }
}

resource "aws_athena_workgroup" "mini_lake" {
  name = "mini-lake-workgroup"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/"
    }
  }
}

