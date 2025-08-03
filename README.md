# PostgreSQL S3 Backup

A lightweight Docker image for automated PostgreSQL database backups to S3-compatible storage with scheduling, encryption, and automatic cleanup features.

**Forked from:** [ariaieboy/pg-backup-s3](https://github.com/ariaieboy/pg-backup-s3) - Full credit to the original authors.

## Features

- 🔄 **Automated Backups**: Schedule backups using cron expressions
- 🗄️ **All Databases**: Backup all databases with a single command
- 🔒 **Encryption**: AES-256-CBC encryption for secure backups
- 🧹 **Auto Cleanup**: Automatically remove old backups based on retention policy
- 🌐 **S3 Compatible**: Works with AWS S3, MinIO, and other S3-compatible storage
- 🐳 **Lightweight**: Based on Alpine Linux with minimal footprint
- 🔐 **Security**: Runs as non-root user

## Quick Start

### Docker Run

```bash
docker run --rm \
  -e POSTGRES_HOST=localhost \
  -e POSTGRES_USER=username \
  -e POSTGRES_PASSWORD=password \
  -e S3_ACCESS_KEY_ID=your-access-key \
  -e S3_SECRET_ACCESS_KEY=your-secret-key \
  -e S3_BUCKET=my-backup-bucket \
  -e S3_ENDPOINT=https://s3.amazonaws.com \
  -e S3_REGION=us-east-1 \
  ghcr.io/jdavid77/pg-backup-s3:main
```

### Docker Compose

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mypassword
      POSTGRES_DB: mydatabase

  pg-backup:
    image: ghcr.io/jdavid77/pg-backup-s3:main
    depends_on:
      - postgres
    environment:
      # Schedule backups (optional - runs once if not set)
      SCHEDULE: '@daily'
      
      # PostgreSQL connection
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mypassword
      POSTGRES_EXTRA_OPTS: '--clean --if-exists'
      
      # S3 configuration
      S3_REGION: us-east-1
      S3_ACCESS_KEY_ID: your-access-key
      S3_SECRET_ACCESS_KEY: your-secret-key
      S3_BUCKET: my-backup-bucket
      S3_PREFIX: postgres-backups
      S3_ENDPOINT: https://s3.amazonaws.com
      
      # Optional features
      ENCRYPTION_PASSWORD: your-encryption-password
      REMOVE_BEFORE: 30  # Remove backups older than 30 days
```

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `POSTGRES_HOST` | PostgreSQL server hostname | `localhost` |
| `POSTGRES_USER` | PostgreSQL username | `postgres` |
| `POSTGRES_PASSWORD` | PostgreSQL password | `mypassword` |
| `S3_ACCESS_KEY_ID` | S3 access key ID | `AKIAIOSFODNN7EXAMPLE` |
| `S3_SECRET_ACCESS_KEY` | S3 secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `S3_BUCKET` | S3 bucket name | `my-backup-bucket` |
| `S3_ENDPOINT` | S3 endpoint URL | `https://s3.amazonaws.com` |
| `S3_REGION` | S3 region | `us-east-1` |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_PORT` | `5432` | PostgreSQL port |
| `POSTGRES_EXTRA_OPTS` | `''` | Additional pg_dumpall options |
| `S3_PREFIX` | `backup` | S3 object key prefix |
| `S3_S3V4` | `no` | Enable S3v4 signature (set to `yes` if needed) |
| `SCHEDULE` | `**None**` | Cron schedule for automatic backups |
| `ENCRYPTION_PASSWORD` | `**None**` | Password for AES-256-CBC encryption |
| `REMOVE_BEFORE` | `''` | Remove backups older than N days |


## Backup File Format

Backups are saved with the following naming pattern:
- **Unencrypted**: `all_2024-01-15T10:30:00Z.sql.gz`
- **Encrypted**: `all_2024-01-15T10:30:00Z.sql.gz.enc`

## Encryption & Decryption

### Enable Encryption
Set the `ENCRYPTION_PASSWORD` environment variable:
```bash
ENCRYPTION_PASSWORD=your-secure-password
```

### Decrypt Backups
```bash
# Download encrypted backup
aws s3 cp s3://your-bucket/backup/all_2024-01-15T10:30:00Z.sql.gz.enc ./

# Decrypt the backup (uses PBKDF2 with 100,000 iterations)
openssl aes-256-cbc -d -pbkdf2 -iter 100000 -in all_2024-01-15T10:30:00Z.sql.gz.enc -out backup.sql.gz -pass pass:your-secure-password

# Extract and restore
gunzip backup.sql.gz
psql -h localhost -U postgres < backup.sql
```

## Automatic Cleanup

Remove old backups automatically by setting `REMOVE_BEFORE`:

```bash
REMOVE_BEFORE=30  # Remove backups older than 30 days
REMOVE_BEFORE=7   # Remove backups older than 7 days
```
