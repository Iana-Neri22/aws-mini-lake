import boto3
import pandas as pd
import io
from datetime import datetime
from botocore.exceptions import ClientError

s3 = boto3.client("s3", endpoint_url="http://localstack:4566")
glue = boto3.client("glue")

def lambda_handler(event, context):

    record = event["Records"][0]
    bucket = record["s3"]["bucket"]["name"]
    key = record["s3"]["object"]["key"]


    # Lê CSV do S3
    response = s3.get_object(Bucket=bucket, Key=key)
    df = pd.read_csv(io.BytesIO(response["Body"].read()))

    # Transformação simples
    df = df.dropna(subset=["transaction_id"])
    df["processed_at"] = datetime.utcnow()

    # Particionamento por data
    partition_date = datetime.utcnow().strftime("%Y-%m-%d")
    output_key = f"dt_reference={partition_date}/transactions.csv"

    buffer = io.BytesIO()
    df.to_csv(buffer, index=False)
    
    s3.put_object(
        Bucket="curated-transactions",
        Key=output_key,
        Body=buffer.getvalue()
    )

    key = urllib.parse.unquote_plus(
        event["Records"][0]["s3"]["object"]["key"]
    )

    dt_reference = key.split("/")[0].split("=")[1]

    try:
        glue.create_partition(
            DatabaseName="mini_lake_db",
            TableName="transactions",
            PartitionInput={
                "Values": [dt_reference],
                "StorageDescriptor": {
                    "Location": f"s3://mini-lake-curated-iana-neri-2026/dt_reference={dt_reference}/",
                    "InputFormat": "org.apache.hadoop.mapred.TextInputFormat",
                    "OutputFormat": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
                    "SerdeInfo": {
                        "SerializationLibrary": "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe",
                        "Parameters": {
                            "field.delim": ","
                        }
                    },
                    "Columns": [
                        {"Name": "transaction_id", "Type": "string"},
                        {"Name": "customer_id", "Type": "string"},
                        {"Name": "amount", "Type": "double"},
                    ],
                }
            }
        )
    except ClientError as e:
        if "AlreadyExistsException" in str(e):
            print("Partition already exists")
        else:
            raise e

    return {"status": "success"}
