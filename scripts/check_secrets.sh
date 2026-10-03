#!/usr/bin/env bash
# Pre-push safety check. Run from anywhere inside the repo:
#   bash scripts/check_secrets.sh
# Exits non-zero if anything sensitive would be committed.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1
fail=0
pass() { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }

files=$(git ls-files -co --exclude-standard)
grep_files() { echo "$files" | xargs -r -d '\n' grep -lF -- "$1" 2>/dev/null; }

echo "== Ignore rules =="
for p in .env .env.local key.pem data.csv dump.sql terraform.tfstate .terraform/x prod.tfvars handbooks/x lectures/x .venv/x; do
  git check-ignore -q "$p" && pass "ignored: $p" || bad "NOT ignored: $p"
done

echo "== Sensitive paths =="
hits=$(echo "$files" | grep -Ei '(^|/)\.env$|\.(csv|sql|sql\.gz|pem|tfstate|tfvars|tmp)$|(^|/)(handbooks|lectures|venv|\.venv|\.terraform)/|Zone\.Identifier$')
[ -z "$hits" ] && pass "no sensitive paths" || bad "sensitive paths: $hits"

echo "== AWS credentials =="
keyids=$(echo "$files" | xargs -r -d '\n' grep -lE 'A(KIA|SIA)[0-9A-Z]{16}' 2>/dev/null)
[ -z "$keyids" ] && pass "no AWS access key IDs" || bad "access key ID pattern in: $keyids"
if [ -f ~/.aws/credentials ]; then
  leaks=0
  while IFS='=' read -r k v; do
    k="${k//[[:space:]]/}"; v="${v//[[:space:]]/}"
    [[ -z "$k" || "$k" == \#* || "$k" == \[* ]] && continue
    [ ${#v} -lt 6 ] && continue
    if [ -n "$(grep_files "$v")" ]; then bad "value of $k from ~/.aws/credentials found in repo files"; leaks=1; fi
  done < ~/.aws/credentials
  [ $leaks -eq 0 ] && pass "no ~/.aws/credentials values in repo files"
else
  echo "SKIP no ~/.aws/credentials"
fi

# Text files only: screenshots still need a manual look before committing.
echo "== AWS account ID =="
acct=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$acct" ]; then
  echo "SKIP could not read account ID (AWS CLI not configured or offline)"
else
  found=$(grep_files "$acct")
  [ -z "$found" ] && pass "account ID not in text files (use <account-id> placeholders)" || bad "account ID found in: $found"
fi

echo "== Line endings =="
crlf=$(echo "$files" | xargs -r -d '\n' file | grep CRLF)
[ -z "$crlf" ] && pass "no CRLF files" || bad "CRLF: $crlf"

echo "== File size (<5MB) =="
big=$(echo "$files" | xargs -r -d '\n' -I{} find {} -maxdepth 0 -size +5M 2>/dev/null)
[ -z "$big" ] && pass "no large files" || bad "large files: $big"

echo
[ $fail -eq 0 ] && echo "ALL CHECKS PASSED" || echo "CHECKS FAILED"
exit $fail
