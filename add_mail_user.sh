#!/bin/bash
#
# sync_users.sh
# Keeps users.csv and the real system mail accounts fully in sync, in BOTH directions:
#
#   1. Any real Linux/mail account that exists but isn't in users.csv yet
#      (e.g. created manually with useradd, or before this system existed)
#      -> gets added to users.csv automatically.
#
#   2. Any new row you add to users.csv by hand (nano users.csv)
#      -> gets a real account created for it (password generated, Maildir set up).
#
# Usage:
#   sudo ./sync_users.sh <domain>
#
# Example:
#   sudo ./sync_users.sh nastp.lab
#
# To add a person going forward, you only ever need to:
#   1. nano users.csv
#   2. Add a line: username,Full Name,username@yourdomain.com,
#      (leave the last field -- date_added -- blank)
#   3. Save, exit, then run: sudo ./sync_users.sh nastp.lab

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)."
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "Usage: sudo $0 <domain>"
  echo "Example: sudo $0 nastp.lab"
  exit 1
fi

DOMAIN="$1"
SCRIPT_DIR="$(dirname "$0")"
USERS_CSV="$SCRIPT_DIR/users.csv"
CREDS_CSV="$SCRIPT_DIR/credentials.csv"

[ -f "$USERS_CSV" ] || echo "username,full_name,email,date_added" > "$USERS_CSV"
[ -f "$CREDS_CSV" ] || echo "username,email,password" > "$CREDS_CSV"

echo "== Step 1: Backfilling existing system accounts into users.csv =="

grep "/home" /etc/passwd | while IFS=: read -r USERNAME PASS UID GID FULLNAME HOMEDIR SHELL; do

  if grep -q "^${USERNAME}," "$USERS_CSV"; then
    continue
  fi

  EMAIL="${USERNAME}@${DOMAIN}"
  DATE_ADDED="$(stat -c '%y' "$HOMEDIR" 2>/dev/null | cut -d'.' -f1)"
  [ -z "$DATE_ADDED" ] && DATE_ADDED="unknown"

  echo "${USERNAME},${FULLNAME},${EMAIL},${DATE_ADDED}" >> "$USERS_CSV"
  echo "➕ Backfilled existing account: $EMAIL"

done

echo ""
echo "== Step 2: Creating real accounts for any new rows in users.csv =="

TMP_FILE="$(mktemp)"
head -n 1 "$USERS_CSV" > "$TMP_FILE"

tail -n +2 "$USERS_CSV" | while IFS=',' read -r USERNAME FULLNAME EMAIL DATE_ADDED; do

  [ -z "$USERNAME" ] && continue

  if id "$USERNAME" &>/dev/null; then
    echo "${USERNAME},${FULLNAME},${EMAIL},${DATE_ADDED}" >> "$TMP_FILE"
    continue
  fi

  PASSWORD="$(openssl rand -base64 12)"
  NOW="$(date '+%Y-%m-%d %H:%M:%S')"

  useradd -m -c "$FULLNAME" -s /usr/sbin/nologin "$USERNAME"
  echo "${USERNAME}:${PASSWORD}" | chpasswd

  mkdir -p "/home/$USERNAME/Maildir/cur" "/home/$USERNAME/Maildir/new" "/home/$USERNAME/Maildir/tmp"
  chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/Maildir"

  echo "${USERNAME},${EMAIL},${PASSWORD}" >> "$CREDS_CSV"
  echo "✅ Created new account: $EMAIL"

  echo "${USERNAME},${FULLNAME},${EMAIL},${NOW}" >> "$TMP_FILE"

done

mv "$TMP_FILE" "$USERS_CSV"

echo ""
echo "Sync complete."
echo "  Full account list: $USERS_CSV"
echo "  New passwords (if any): $CREDS_CSV"
