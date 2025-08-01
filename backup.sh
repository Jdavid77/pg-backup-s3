#!/usr/bin/env sh

set -eou pipefail

log() {
  echo "[`date -u +"%Y-%m-%dT%H:%M:%SZ"`] $*"
}

require_env() {
  eval "VAL=\${$1}"
  if [ -z \"$VAL\" ]; then
    echo "❌ Environment variable $1 is required."
    exit 1
  fi
}

require_env POSTGRES_HOST
require_env POSTGRES_PORT
require_env POSTGRES_USER
require_env POSTGRES_PASSWORD
require_env S3_BUCKET
require_env S3_ACCESS_KEY_ID
require_env S3_SECRET_ACCESS_KEY
require_env S3_ENDPOINT
require_env S3_REGION

# AWS

export AWS_ARGS="--endpoint-url ${S3_ENDPOINT}"
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

if [ -z ${S3_PREFIX+x} ]; then
  S3_PREFIX="/"
else
  S3_PREFIX="/${S3_PREFIX}/"
fi

# Backup File

export SRC_FILE=/tmp/dump.sql.gz
export DEST_FILE=all_$(date +"%Y-%m-%dT%H:%M:%SZ").sql.gz

# Postgres

export PGPASSWORD=$POSTGRES_PASSWORD

# Test connections

log "Testing connection..."

if ! pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" >/dev/null 2>&1; then
  log "Cannot connect to PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT"
  exit 1
else
  log "PostgreSQL connection successful"
fi


POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"

log "Creating dump of all databases from ${POSTGRES_HOST}..."
pg_dumpall -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER | gzip > $SRC_FILE

if [ "${ENCRYPTION_PASSWORD}" != "**None**" ]; then
  log "Encrypting ${SRC_FILE}"
  openssl enc -aes-256-cbc -in $SRC_FILE -out ${SRC_FILE}.enc -k $ENCRYPTION_PASSWORD
  if [ $? != 0 ]; then
    >&2 log "Error encrypting ${SRC_FILE}"
  fi
  rm $SRC_FILE
  SRC_FILE="${SRC_FILE}.enc"
  DEST_FILE="${DEST_FILE}.enc"
fi

log "Uploading dump to $S3_BUCKET"
cat $SRC_FILE | aws $AWS_ARGS s3 cp - "s3://${S3_BUCKET}${S3_PREFIX}${DEST_FILE}" || exit 2

log "SQL backup uploaded successfully"
rm -rf $SRC_FILE

if [ -n "$REMOVE_BEFORE" ]; then
  # Calculate the cutoff date (using coreutils date command)
  date_from_remove=$(date -d "${REMOVE_BEFORE} days ago" +%Y-%m-%d)
  backups_query="Contents[?LastModified<='${date_from_remove} 00:00:00'].{Key: Key}"

  log "Removing old backups from $S3_BUCKET (older than ${date_from_remove})..."
  
  # First, check if there are any objects to remove
  if [ -z "$S3_PREFIX" ]; then
        # No prefix - list all objects in bucket
        old_backups=$(aws s3api list-objects \
          --bucket "${S3_BUCKET}" \
          --query "${backups_query}" \
          --output text \
          $AWS_ARGS 2>/dev/null || echo "")
  else
        # Use prefix to limit scope
        old_backups=$(aws s3api list-objects \
          --bucket "${S3_BUCKET}" \
          --prefix "${S3_PREFIX}" \
          --query "${backups_query}" \
          --output text \
          $AWS_ARGS 2>/dev/null || echo "")
  fi
  
  if [ -n "$old_backups" ] && [ "$old_backups" != "None" ]; then
    log "Found old backups to remove..."
    log "$old_backups" | xargs -n1 -t -I 'KEY' aws s3 rm s3://${S3_BUCKET}/KEY $AWS_ARGS
    log "Removal complete."
  else
    log "No old backups found to remove."
  fi

fi

