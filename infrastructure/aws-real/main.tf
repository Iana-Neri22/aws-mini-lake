resource "aws_s3_bucket" "curated" {
  bucket = "mini-lake-curated-iana-neri-2026"
}

resource "aws_s3_bucket" "athena_results" {
  bucket = "mini-lake-athena-results-iana-neri-2026"
}

resource "aws_glue_catalog_database" "analytics" {
  name = "mini_lake_db"
}

resource "aws_athena_workgroup" "mini_lake" {
  name = "mini-lake-workgroup"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/"
    }
  }
}

resource "aws_glue_catalog_table" "transactions" {
  name          = "transactions"
  database_name = aws_glue_catalog_database.analytics.name
  table_type    = "EXTERNAL_TABLE"

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
      type = "double"
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

  parameters = {
    "skip.header.line.count" = "1"
  }
}

