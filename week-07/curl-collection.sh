#!/usr/bin/env bash
# Week 7 — curl checks for the serverless property read path.
# Replace API with your API Gateway Invoke URL from Stages → $default.

set -euo pipefail

API="${API:-https://v5hv32x5n0.execute-api.us-east-1.amazonaws.com}"

echo "== GET /properties/R100234 =="
curl -sS "$API/properties/R100234"
echo

echo "== GET /properties/R100235 =="
curl -sS "$API/properties/R100235"
echo

echo "== HTTP status for R100234 =="
curl -sS -o /dev/null -w "%{http_code}\n" "$API/properties/R100234"
