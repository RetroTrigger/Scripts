#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# Headless VirtualBox + phpVirtualBox installer
# Target: Debian 13 (Trixie), amd64, bare metal
#
# Optional environment variables:
#   VBOX_USER=vbox
#   VBOX_PASSWORD='strong-service-password'
#   WEB_USER=admin
#   WEB_PASSWORD='strong-web-password'
#   HOSTNAME_FQDN=vbox.example.local
#   VM_DIR=/srv/virtualbox/vms
#   ISO_DIR=/srv/virtualbox/isos
#
# Example:
# sudo VBOX_PASSWORD='change-me-1' WEB_PASSWORD='change-me-2' \
#   HOSTNAME_FQDN='vbox.home.arpa' bash install-phpvirtualbox.sh

trap 'echo "[ERROR] Installation failed on line $LINENO." >&2' ERR

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run this script as root or with sudo."
[[ -r /etc/os-release ]] || die "Cannot identify the operating system."

. /etc/os-release
[[ "${ID:-}" == "debian" ]] || die "This installer supports Debian only."
[[ "${VERSION_CODENAME:-}" == "trixie" ]] || \
  die "Debian 13 (trixie) is required. Detected: ${PRETTY_NAME:-unknown}."
[[ "$(dpkg --print-architecture)" == "amd64" ]] || \
  die "phpVirtualBox 7.2 currently requires an x86/amd64 VirtualBox host."

VBOX_USER="${VBOX_USER:-vbox}"
WEB_USER="${WEB_USER:-admin}"
HOSTNAME_FQDN="${HOSTNAME_FQDN:-$(hostname -f 2>/dev/null || hostname)}"
VM_DIR="${VM_DIR:-/srv/virtualbox/vms}"
ISO_DIR="${ISO_DIR:-/srv/virtualbox/isos}"
WEB_ROOT="/var/www/phpvirtualbox"
PHPVBOX_VERSION="7.2-3"
VBOX_WEBSERVICE_PORT="18083"

read_secret() {
  local var_name="$1" prompt="$2" value="${!var_name:-}"
  if [[ -z "$value" ]]; then
    read -r -s -p "$prompt: " value
    echo
    [[ -n "$value" ]] || die "$var_name cannot be empty."
    printf -v "$var_name" '%s' "$value"
  fi
}

read_secret VBOX_PASSWORD "Password for the local VirtualBox service account '$VBOX_USER'"
read_secret WEB_PASSWORD "Password for the Apache web login '$WEB_USER'"

[[ ${#VBOX_PASSWORD} -ge 12 ]] || warn "The VirtualBox service password is shorter than 12 characters."
[[ ${#WEB_PASSWORD} -ge 12 ]] || warn "The web password is shorter than 12 characters."

log "Installing base packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  apache2 apache2-utils ca-certificates curl gnupg openssl unzip \
  build-essential dkms linux-headers-amd64 \
  php php-soap php-xml php-mbstring php-curl php-zip libapache2-mod-php

log "Adding Oracle's signed VirtualBox repository"
install -d -m 0755 /usr/share/keyrings
curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc \
  | gpg --dearmor --yes -o /usr/share/keyrings/oracle-virtualbox-2016.gpg

cat >/etc/apt/sources.list.d/virtualbox.list <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian trixie contrib
EOF

apt-get update
apt-get install -y virtualbox-7.2

log "Creating the dedicated VirtualBox account and storage"
if ! id "$VBOX_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$VBOX_USER"
fi
echo "${VBOX_USER}:${VBOX_PASSWORD}" | chpasswd
usermod -aG vboxusers "$VBOX_USER"

install -d -o "$VBOX_USER" -g "$VBOX_USER" -m 0750 "$VM_DIR" "$ISO_DIR"
sudo -u "$VBOX_USER" VBoxManage setproperty machinefolder "$VM_DIR"

log "Configuring vboxwebsrv"
cat >/etc/default/virtualbox <<EOF
VBOXWEB_USER=${VBOX_USER}
VBOXWEB_HOST=127.0.0.1
VBOXWEB_PORT=${VBOX_WEBSERVICE_PORT}
VBOXWEB_TIMEOUT=0
VBOXWEB_CHECK_INTERVAL=5
VBOXWEB_THREADS=100
EOF

cat >/etc/systemd/system/vboxweb-service.service <<EOF
[Unit]
Description=VirtualBox Web Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${VBOX_USER}
Group=${VBOX_USER}
Environment=HOME=/home/${VBOX_USER}
ExecStart=/usr/bin/vboxwebsrv --host 127.0.0.1 --port ${VBOX_WEBSERVICE_PORT} --timeout 0
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/home/${VBOX_USER} ${VM_DIR} ${ISO_DIR}
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vboxweb-service.service

log "Installing phpVirtualBox ${PHPVBOX_VERSION}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

curl -fL \
  "https://github.com/phpvirtualbox/phpvirtualbox/archive/refs/tags/${PHPVBOX_VERSION}.zip" \
  -o "$tmpdir/phpvirtualbox.zip"
unzip -q "$tmpdir/phpvirtualbox.zip" -d "$tmpdir"

rm -rf "$WEB_ROOT"
mv "$tmpdir/phpvirtualbox-${PHPVBOX_VERSION}" "$WEB_ROOT"
chown -R root:www-data "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 0750 {} +
find "$WEB_ROOT" -type f -exec chmod 0640 {} +

cat >"$WEB_ROOT/config.php" <<EOF
<?php
class phpVBoxConfig {
    var \$username = '${VBOX_USER}';
    var \$password = '${VBOX_PASSWORD}';
    var \$location = 'http://127.0.0.1:${VBOX_WEBSERVICE_PORT}/';
    var \$language = 'en';
    var \$vrdeports = '9000-9100';
    var \$maxProgressList = 5;
    var \$deleteOnRemove = true;
    var \$browserRestrictFiles = array(
        '.iso','.vdi','.vmdk','.img','.bin','.vhd','.hdd',
        '.ovf','.ova','.xml','.vbox','.cdr','.dmg','.ima','.dsk','.vfd'
    );
    var \$browserRestrictFolders = array('${VM_DIR}','${ISO_DIR}');
    var \$hostMemInfoRefreshInterval = 5;
}
EOF
chown root:www-data "$WEB_ROOT/config.php"
chmod 0640 "$WEB_ROOT/config.php"

log "Creating an HTTPS-only Apache site"
install -d -m 0750 -o root -g www-data /etc/apache2/phpvirtualbox
htpasswd -bBc /etc/apache2/phpvirtualbox/.htpasswd "$WEB_USER" "$WEB_PASSWORD"
chown root:www-data /etc/apache2/phpvirtualbox/.htpasswd
chmod 0640 /etc/apache2/phpvirtualbox/.htpasswd

install -d -m 0755 /etc/ssl/phpvirtualbox
openssl req -x509 -nodes -newkey rsa:3072 -days 825 \
  -keyout /etc/ssl/phpvirtualbox/phpvirtualbox.key \
  -out /etc/ssl/phpvirtualbox/phpvirtualbox.crt \
  -subj "/CN=${HOSTNAME_FQDN}" \
  -addext "subjectAltName=DNS:${HOSTNAME_FQDN},DNS:$(hostname),IP:127.0.0.1"
chmod 0600 /etc/ssl/phpvirtualbox/phpvirtualbox.key
chmod 0644 /etc/ssl/phpvirtualbox/phpvirtualbox.crt

cat >/etc/apache2/sites-available/phpvirtualbox.conf <<EOF
<VirtualHost *:80>
    ServerName ${HOSTNAME_FQDN}
    Redirect permanent / https://${HOSTNAME_FQDN}/
</VirtualHost>

<VirtualHost *:443>
    ServerName ${HOSTNAME_FQDN}
    DocumentRoot ${WEB_ROOT}

    SSLEngine on
    SSLCertificateFile /etc/ssl/phpvirtualbox/phpvirtualbox.crt
    SSLCertificateKeyFile /etc/ssl/phpvirtualbox/phpvirtualbox.key

    <Directory ${WEB_ROOT}>
        Options FollowSymLinks
        AllowOverride None
        Require valid-user
        AuthType Basic
        AuthName "phpVirtualBox"
        AuthUserFile /etc/apache2/phpvirtualbox/.htpasswd
        DirectoryIndex index.html
    </Directory>

    <FilesMatch "^(\.git|config\.php|recovery\.php)">
        Require all denied
    </FilesMatch>

    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set Referrer-Policy "same-origin"
    Header always set Permissions-Policy "camera=(), microphone=(), geolocation=()"

    ErrorLog \${APACHE_LOG_DIR}/phpvirtualbox-error.log
    CustomLog \${APACHE_LOG_DIR}/phpvirtualbox-access.log combined
</VirtualHost>
EOF

a2enmod ssl headers
a2dissite 000-default.conf >/dev/null
a2ensite phpvirtualbox.conf >/dev/null
apache2ctl configtest
systemctl enable --now apache2
systemctl reload apache2

log "Verifying services and kernel modules"
modprobe vboxdrv
systemctl is-active --quiet vboxweb-service.service || \
  die "vboxweb-service did not start. Run: journalctl -u vboxweb-service -n 100"
systemctl is-active --quiet apache2 || \
  die "Apache did not start. Run: journalctl -u apache2 -n 100"

SERVER_IP="$(hostname -I | awk '{print $1}')"

cat <<EOF

Installation complete.

Open:
  https://${HOSTNAME_FQDN}/
or:
  https://${SERVER_IP:-SERVER-IP}/

Apache login:
  Username: ${WEB_USER}
  Password: the WEB_PASSWORD entered during installation

phpVirtualBox's initial application login:
  Username: admin
  Password: admin

IMPORTANT:
  1. Accept the self-signed certificate warning, or replace the certificate
     with one from your own CA / Let's Encrypt.
  2. Immediately change phpVirtualBox's admin/admin application password.
  3. Do not expose this interface or ports 18083/9000-9100 directly to the
     public Internet. Use a VPN such as Tailscale or restrict access by firewall.
  4. Place ISO images in: ${ISO_DIR}
  5. Virtual machines are stored in: ${VM_DIR}

Useful checks:
  systemctl status vboxweb-service
  systemctl status apache2
  VBoxManage --version
  sudo -u ${VBOX_USER} VBoxManage list vms
  journalctl -u vboxweb-service -f
EOF
