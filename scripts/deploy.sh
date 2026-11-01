#!/usr/bin/env bash
# Runs on app server. Started by GitHub Actions over SSH.
set -euo pipefail

APP_DIR=/var/www/guestbook
cd "$APP_DIR"

echo "==> Fetching latest code"
git fetch origin main
git reset --hard origin/main

echo "==> Installing dependencies"
composer install --no-dev --optimize-autoloader --no-interaction

echo "==> Running migrations"
php artisan migrate --force

echo "==> Rebuilding caches"
php artisan config:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo "==> Reloading PHP-FPM"
sudo /usr/bin/systemctl reload php8.5-fpm

echo "==> Deploy finished"
