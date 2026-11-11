# Week 7 — Serverless property read path

I took the same lookup PropertyLite does for `GET /properties/<id>` and hosted it without an always-on EC2: **API Gateway → Lambda → DynamoDB**. I also created an SQS queue with a dead-letter queue. Resources were torn down after the write-up (or are listed below for cleanup).

## Request path

```text
Laptop (curl)
    │  HTTPS GET /properties/{id}
    ▼
API Gateway HTTP API  (property-http-api)
    │  invokes Lambda (payload format 2.0)
    ▼
Lambda  get-property  (Python 3.12)
    │  dynamodb:GetItem on partition key L_ListingID
    ▼
DynamoDB table  Properties
    │
    ▼
JSON listing body back to the client
```

No bastion, no ALB, no Auto Scaling. The function runs only when a request arrives.

## What I built

| Piece | Name / setting |
|---|---|
| DynamoDB | `Properties`, partition key `L_ListingID` (S), `PAY_PER_REQUEST`; sample rows `R100234`–`R100236` |
| Lambda | `get-property`, Python 3.12, handler in [`lambda_function.py`](lambda_function.py) |
| IAM | Inline policy `get-property-dynamodb-read` on the Lambda execution role — `GetItem` / `DescribeTable` only on `arn:aws:dynamodb:us-east-1:<account-id>:table/Properties` |
| API Gateway | HTTP API `property-http-api`, route **GET** `/properties/{id}`, integration Lambda payload **2.0**, stage `$default` (auto-deploy) |
| SQS | `property-queue` with redrive to `property-dlq` after `maxReceiveCount` 3 |

I did **not** attach `AmazonDynamoDBReadOnlyAccess`. The role can reach this one table and nothing else in the account for DynamoDB.

## Prove it (curl)

Invoke URL shape: `https://<api-id>.execute-api.us-east-1.amazonaws.com`  
(Mine was `https://v5hv32x5n0.execute-api.us-east-1.amazonaws.com`.)

```bash
API=https://v5hv32x5n0.execute-api.us-east-1.amazonaws.com
curl -s "$API/properties/R100234"
```

Returned the Sacramento listing (`L_ListingID` `R100234`, `L_City` `Sacramento`, `L_SystemPrice` `450000`, …) — same shape as PropertyLite on EC2, served with zero always-on compute.

A small script with the same checks is in [`curl-collection.sh`](curl-collection.sh):

```bash
chmod +x week-07/curl-collection.sh
API=https://v5hv32x5n0.execute-api.us-east-1.amazonaws.com ./week-07/curl-collection.sh
```

## SQS + dead-letter queue

```text
send-message → property-queue
                  │
                  │  if a consumer fails the same message 3 times
                  ▼
               property-dlq
```

I created `property-dlq`, then `property-queue` with a `RedrivePolicy` pointing at the DLQ ARN and `maxReceiveCount` 3. `send-message` with `{"PropertyId":"P1002"}` and `receive-message` returned that body.

## Debug note (Lab 7.3)

If the API returns `{"message":"Internal Server Error"}`, the first place to look is Lambda → Monitor → CloudWatch Logs — not the curl body alone. The usual causes here are a wrong DynamoDB table ARN on the role, or a route without `{id}` so `pathParameters` is missing.

## Cleanup

When finished: delete the HTTP API, Lambda function, IAM inline policy/role if unused, DynamoDB table `Properties`, and SQS queues `property-queue` then `property-dlq`.
