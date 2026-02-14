# Event-Driven Mini Data Lake on AWS (LocalStack)

This project simulates an event-driven data lake architecture using AWS services via LocalStack.

The pipeline ingests CSV transaction files into a raw S3 bucket, processes them using AWS Lambda (with Pandas), and stores curated, partitioned data in a separate S3 bucket.

The goal is to demonstrate serverless data engineering patterns, infrastructure setup, packaging strategies, and architectural trade-offs when working with AWS Lambda.

---

## 🏗️ Architecture

![Event-Driven Data Lake Architecture](architecture/event-driven-mini-lake.png)


---

## 🧰 Technologies Used

- Amazon Web Services (simulated)
- LocalStack
- Amazon S3
- AWS Lambda
- Pandas
- Docker
- AWS CLI

---

## ⚙️ Setup Instructions

### 1️⃣ Start LocalStack

```bash
docker-compose up -d
```

2️⃣ Create S3 Buckets

```bash
aws --endpoint-url=http://localhost:4566 s3 mb s3://raw-transactions
aws --endpoint-url=http://localhost:4566 s3 mb s3://curated-transactions
```

3️⃣ Package Lambda with Pandas (Lambda-Compatible Build)

Clean previous builds:

```bash
rm -rf package function.zip
mkdir package
```

Install pandas using AWS-compatible build image:

```bash
docker run --rm -v "$PWD/package":/var/task \
  public.ecr.aws/sam/build-python3.9 \
  pip install pandas -t /var/task
```

Copy handler:

```bash
cp lambda/handler.py package/
```

Zip contents (from inside package directory):

```bash
cd package
zip -r ../function.zip .
cd ..
```

4️⃣ Create IAM Role (LocalStack)

```bash
aws --endpoint-url=http://localhost:4566 iam create-role \
  --role-name lambda-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'
```

5️⃣ Create Lambda Function

```bash
aws --endpoint-url=http://localhost:4566 lambda create-function \
  --function-name process-transactions \
  --runtime python3.9 \
  --handler handler.lambda_handler \
  --zip-file fileb://function.zip \
  --role arn:aws:iam::000000000000:role/lambda-role
  ```

Verify:

```bash
aws --endpoint-url=http://localhost:4566 lambda list-functions
```

6️⃣ Upload Sample File (Raw Layer)

```bash
aws --endpoint-url=http://localhost:4566 s3 cp sample_data/transactions.csv s3://raw-transactions/
```

7️⃣ Invoke Lambda Manually

```bash
aws --endpoint-url=http://localhost:4566 lambda invoke \
  --function-name process-transactions \
  --cli-binary-format raw-in-base64-out \
  --payload file://event.json \
  response.json \
  --no-cli-pager
```

Check response:

```bash
cat response.json
```

8️⃣ Validate Curated Output

```bash
aws --endpoint-url=http://localhost:4566 s3 ls s3://curated-transactions/ --recursive
```

You should see partitioned output like:

dt_reference=YYYY-MM-DD/transactions.csv

---

## 🧠 Architectural Challenges & Learnings

Handling AWS Lambda dependency packaging

Working around the 250MB unzipped Lambda size limit

Understanding Lambda runtime isolation

Event-driven architecture fundamentals

Local AWS environment simulation using LocalStack

Trade-offs between Parquet support and Lambda constraints

---

## 🚀 Future Improvements

Automate S3 trigger instead of manual invocation

Infrastructure as Code with Terraform

Add Athena table for querying curated layer

Implement Lambda Layers

Container-based Lambda version

Add CI/CD pipeline