#!/usr/bin/env bash
# Hourly MySQL backup. Dumps guestbook from db-vm over the private network.
set -euo pipefail

DB_HOST=172.31.38.213
DB_NAME=guestbook
BACKUP_DIR=/var/backups/guestbook
CONF=/home/backup/.my.cnf
LOG=/home/backup/backup.log
RETENTION_DAYS=7

STAMP=$(date +%Y-%m-%d_%H-%M-%S)
FINAL="$BACKUP_DIR/${DB_NAME}_${STAMP}.sql.gz"
TMP="$FINAL.partial"

log() { echo "$(date +%F\ %T) [$1] $2" >> "$LOG"; }

umask 077

# 1. Dump and compress. A failed dump leaves no file behind.
if mysqldump --defaults-extra-file="$CONF" --host="$DB_HOST" \
     --single-transaction --routines --triggers --no-tablespaces \
     "$DB_NAME" 2>>"$LOG" | gzip -9 > "$TMP"; then
  # 2. Verify: gzip must be intact and the dump must end with MySQL's completion line.
  if gzip -t "$TMP" && zcat "$TMP" | tail -n 1 | grep -q "Dump completed"; then
    mv "$TMP" "$FINAL"
    log INFO "backup OK: $(basename "$FINAL") ($(du -h "$FINAL" | cut -f1))"
  else
    rm -f "$TMP"
    log ERROR "backup incomplete, partial file deleted"
    exit 1
  fi
else
  rm -f "$TMP"
  log ERROR "mysqldump failed, partial file deleted"
  exit 1
fi

# 3. Retention: delete backups older than RETENTION_DAYS.
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete
find "$BACKUP_DIR" -name "*.partial" -delete
log INFO "retention applied, kept last ${RETENTION_DAYS} days"
