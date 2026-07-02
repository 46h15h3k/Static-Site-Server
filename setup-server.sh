#!/usr/bin/env bash
#
# setup-server.sh — run this ON the EC2 instance once, over SSH, to provision nginx.
# Written for Amazon Linux 2023 (dnf, no sites-available/sites-enabled, SELinux enforcing).
#
#   scp -i key.pem setup-server.sh nginx/static-site.conf ec2-user@<ip>:~/
#   ssh -i key.pem ec2-user@<ip>
#   chmod +x setup-server.sh && sudo ./setup-server.sh
#
# Idempotent: safe to re-run.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this with sudo: sudo ./setup-server.sh" >&2
  exit 1
fi

REMOTE_USER_NAME="${SUDO_USER:-ec2-user}"

echo "Installing nginx..."
dnf install -y nginx

echo "Creating site directory..."
mkdir -p /var/www/site
chown -R "$REMOTE_USER_NAME":"$REMOTE_USER_NAME" /var/www/site

# Amazon Linux's nginx.conf includes /etc/nginx/conf.d/*.conf directly —
# there's no sites-available/sites-enabled split like on Debian/Ubuntu.
CONF_SRC="$(dirname "${BASH_SOURCE[0]}")/static-site.conf"
if [[ -f "$CONF_SRC" ]]; then
  echo "Installing nginx server block..."
  cp "$CONF_SRC" /etc/nginx/conf.d/static-site.conf
else
  echo "static-site.conf not found next to this script — copy it manually to /etc/nginx/conf.d/ and re-run, or configure nginx by hand." >&2
fi

# The stock nginx.conf ships a default "server { listen 80 default_server; ... }"
# block pointing at /usr/share/nginx/html. Comment it out so it doesn't win
# ties for port 80 against our own server block.
if grep -q "root         /usr/share/nginx/html;" /etc/nginx/nginx.conf 2>/dev/null; then
  echo "Note: /etc/nginx/nginx.conf still has its own built-in server block."
  echo "If your site doesn't come up, comment out that block (the one listening"
  echo "on port 80 with root /usr/share/nginx/html) and re-run 'nginx -t'."
fi

# SELinux is enforcing by default on Amazon Linux 2023. Without this, nginx
# gets "Permission denied" reading anything outside its expected content paths.
if command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce)" != "Disabled" ]]; then
  echo "SELinux detected — labeling /var/www/site for nginx..."
  if ! command -v semanage >/dev/null 2>&1; then
    dnf install -y policycoreutils-python-utils
  fi
  semanage fcontext -a -t httpd_sys_content_t "/var/www/site(/.*)?" 2>/dev/null || true
  restorecon -Rv /var/www/site
fi

echo "Testing nginx config..."
nginx -t

echo "Enabling and starting nginx..."
systemctl enable nginx
systemctl restart nginx

echo
echo "Done. Nginx is serving /var/www/site on port 80."
echo "rsync your local ./site/ folder there next, e.g. via ./deploy.sh from your machine."
