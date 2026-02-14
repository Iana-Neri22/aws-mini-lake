import boto3
import pandas as pd
import io
from datetime import datetime

s3 = boto3.client("s3", endpoint_url="http://localstack:4566")

def lambda_handler(event, context):

    bucket = event["bucket"]
    key = event["key"]

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

    return {"status": "success"}
