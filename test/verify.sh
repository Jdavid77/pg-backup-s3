#!/usr/bin/env sh
# Check the backup service uploaded one complete dump containing the seeded row.

set -euo pipefail

fail() {
  echo "FAIL: $*"
  exit 1
}

export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY"

aws="aws --endpoint-url $S3_ENDPOINT --region $S3_REGION"
key=$($aws s3api list-objects-v2 --bucket "$S3_BUCKET" --prefix "$S3_PREFIX/" --query 'Contents[].Key' --output text)

[ "$(echo "$key" | wc -w)" -eq 1 ] || fail "expected one backup, found: $key"

echo "Found $key"

if [ "$ENCRYPTION_PASSWORD" = "**None**" ]; then
  case "$key" in
    *.sql.gz)
      ;;
    *)
      fail "no encryption password set, but got $key"
      ;;
  esac

  $aws s3 cp "s3://$S3_BUCKET/$key" - | gunzip > /tmp/dump.sql
else
  case "$key" in
    *.sql.gz.enc)
      ;;
    *)
      fail "encryption password set, but got $key"
      ;;
  esac

  $aws s3 cp "s3://$S3_BUCKET/$key" - \
    | openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -pass "pass:$ENCRYPTION_PASSWORD" \
    | gunzip > /tmp/dump.sql
fi

grep -q "PostgreSQL database cluster dump complete" /tmp/dump.sql || fail "dump is incomplete"
grep -q "backed-up" /tmp/dump.sql || fail "seeded row missing from dump"

echo "PASS"
