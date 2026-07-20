#!/bin/bash
#
# add_mail_user.sh
# Creates a Linux system user for mail (Postfix/Dovecot) and logs it
# into users.csv so you have a running record of every account you create.
#
# Usage:
#   sudo ./add_mail_user.sh <username> <full name> <domain>
#
# Example:
#   sudo ./add_mail_user.sh john.doe "John Doe" myorg.com
#
# This will:
#   1. Create the Linux user (john.doe)
#   2. Prompt you to set a password for it (used for mail login too)
#   3. Create their Maildir
#   4. Record username, email, full name, and creation date in users.csv

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)."
  exit 1
fi

if [ $# -lt 3 ]; then
  echo "Usage: sudo $0 <username> <full name> <domain>"
  echo "Example: sudo $0 john.doe \"John Doe\" myorg.com"
  exit 1
fi

USERNAME="$1"
FULLNAME="$2"
DOMAIN="$3"
EMAIL="${USERNAME}@${DOMAIN}"
CSV_FILE="$(dirname "$0")/users.csv"
DATE_ADDED="$(date '+%Y-%m-%d %H:%M:%S')"

# Check if user already exists
if id "$USERNAME" &>/dev/null; then
  echo "Error: user '$USERNAME' already exists on this system."
  exit 1
fi

# Create CSV with header if it doesn't exist yet
if [ ! -f "$CSV_FILE" ]; then
  echo "username,full_name,email,date_added" > "$CSV_FILE"
fi

# Create the actual system/mail user
useradd -m -c "$FULLNAME" -s /usr/sbin/nologin "$USERNAME"

echo ""
echo "Set a mailbox password for $USERNAME:"
passwd "$USERNAME"

# Create Maildir (Dovecot usually expects this under the home dir)
mkdir -p "/home/$USERNAME/Maildir/cur" "/home/$USERNAME/Maildir/new" "/home/$USERNAME/Maildir/tmp"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/Maildir"

# Log it into the CSV
echo "${USERNAME},${FULLNAME},${EMAIL},${DATE_ADDED}" >> "$CSV_FILE"

echo ""
echo "✅ Created mail account:"
echo "   Email:    $EMAIL"
echo "   Username: $USERNAME"
echo "   Logged in: $CSV_FILE"
