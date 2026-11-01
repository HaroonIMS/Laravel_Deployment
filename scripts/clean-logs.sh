#!/usr/bin/env bash
# Nightly log hygiene for storage/logs. Safe to run repeatedly.
set -euo pipefail

LOG_DIR=/var/www/guestbook/storage/logs
WARN_LOG=/home/deploy/logs-cleanup.log
MAX_MB=500
DELETE_AFTER_DAYS=14
TODAY_FILE="laravel-$(date +%F).log"

log() { echo "$(date +%F\ %T) $*" >> "$WARN_LOG"; }

# 1. Compress daily logs older than one day. Today's log is never touched.
find "$LOG_DIR" -maxdepth 1 -type f -name "laravel-*.log" ! -name "$TODAY_FILE" -mtime +0 -exec gzip -9 {} +

# 2. Delete compressed logs older than DELETE_AFTER_DAYS. Only laravel-*.log.gz matches,
#    so .gitignore and any other file in the folder are never touched.
find "$LOG_DIR" -maxdepth 1 -type f -name "laravel-*.log.gz" -mtime +"$DELETE_AFTER_DAYS" -delete

# 3. Warn in our own log if the folder is larger than MAX_MB.
SIZE_MB=$(du -sm "$LOG_DIR" | cut -f1)
if [ "$SIZE_MB" -gt "$MAX_MB" ]; then
  log "WARNING: $LOG_DIR is ${SIZE_MB} MB, above the ${MAX_MB} MB limit"
fi
log "run complete, folder is ${SIZE_MB} MB"
