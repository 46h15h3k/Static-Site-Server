#!/usr/bin/env bash
#
# setup-server.sh — run this ON the EC2 instance once, over SSH, to provision nginx.
# Written for Ubuntu 26.04 LTS (apt, sites-available/sites-enabled split, AppArmor enforcing).
#
#   scp -i key.pem setup-server.sh nginx/static-site.conf ubuntu@<ip>:~/
#   ssh -i key.pem ubuntu@<ip>
#   chmod +x setup-server.sh && sudo ./setup-server.sh
#
# Idempotent: safe to re-run.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this with sudo: sudo ./setup-server-ubuntu.sh" >&2
  exit 1
fi

REMOTE_USER_NAME="${SUDO_USER:-ubuntu}"

echo "Updating package index..."
apt-get update -y

echo "Installing nginx..."
apt-get install -y nginx

echo "Creating site directory..."
mkdir -p /var/www/site
chown -R "$REMOTE_USER_NAME":"$REMOTE_USER_NAME" /var/www/site

# Ubuntu's nginx.conf includes /etc/nginx/sites-enabled/*.conf, which is
# normally a set of symlinks into /etc/nginx/sites-available/ — unlike
# Amazon Linux, where configs just drop straight into conf.d/.
CONF_SRC="$(dirname "${BASH_SOURCE[0]}")/static-site.conf"
if [[ -f "$CONF_SRC" ]]; then
  echo "Installing nginx server block..."
  cp "$CONF_SRC" /etc/nginx/sites-available/static-site.conf
  ln -sf /etc/nginx/sites-available/static-site.conf /etc/nginx/sites-enabled/static-site.conf
else
  echo "static-site.conf not found next to this script — copy it manually to /etc/nginx/sites-available/ and symlink it into sites-enabled/, or configure nginx by hand." >&2
fi

# Ubuntu ships a "default" server block in sites-available/, symlinked into
# sites-enabled/, listening on port 80 and pointing at /var/www/html. Disable
# it so it doesn't win ties for port 80 against our own server block.
if [[ -L /etc/nginx/sites-enabled/default ]]; then
  echo "Disabling the default nginx site..."
  rm -f /etc/nginx/sites-enabled/default
fi

# AppArmor is enforcing by default on Ubuntu. nginx's profile normally
# already covers /var/www/**, but confirm it's not blocking access.
if command -v aa-status >/dev/null 2>&1 && aa-status --enabled 2>/dev/null; then
  echo "AppArmor detected — checking nginx profile status..."
  if aa-status 2>/dev/null | grep -q "usr.sbin.nginx"; then
    echo "nginx AppArmor profile is loaded. /var/www is covered by the default profile;"
    echo "if you see 'Permission denied' errors, check 'sudo aa-status' and"
    echo "'/var/log/syslog' for DENIED entries against nginx."
  fi
fi

echo "Testing nginx config..."
nginx -t

echo "Enabling and starting nginx..."
systemctl enable nginx
systemctl restart nginx

# Ubuntu images commonly run ufw. If it's active, make sure HTTP is allowed.
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  echo "ufw is active — allowing HTTP (port 80)..."
  ufw allow 'Nginx HTTP' 2>/dev/null || ufw allow 80/tcp
fi

echo
echo "Done. Nginx is serving /var/www/site on port 80."
echo "rsync your local ./site/ folder there next, e.g. via ./deploy.sh from your machine."
