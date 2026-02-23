#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Bitwarden -> restore GitHub SSH key (attachment method)
# Does:
#   - Installs Bitwarden CLI + deps (Debian/Ubuntu/Proxmox, Alpine, Arch, RHEL-based)
#   - Logs in/unlocks vault, downloads SSH private key as ATTACHMENT
#   - Writes ~/.ssh/id_ed25519_github (+ .pub), sets perms, adds ssh config
#
# REQUIREMENTS IN YOUR VAULT:
#   - A Bitwarden item (Secure Note is fine) named exactly KEY_ITEM_NAME
#   - It has a FILE ATTACHMENT named exactly KEY_ATTACHMENT_NAME
#     containing the *private key* (e.g., id_ed25519_github)
# ============================================================

KEY_ITEM_NAME="${KEY_ITEM_NAME:-GitHub SSH Key}"
KEY_ATTACHMENT_NAME="${KEY_ATTACHMENT_NAME:-id_ed25519_github}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519_github}"
SSH_CONFIG_PATH="${SSH_CONFIG_PATH:-$HOME/.ssh/config}"
BW_SERVER="${BW_SERVER:-}"     # optional, set if self-hosted; e.g. https://vault.example.com
NONINTERACTIVE="${NONINTERACTIVE:-0}"  # set to 1 for CI if you're already logged in/unlocked

need_cmd() { command -v "$1" >/dev/null 2>&1; }

install_debian_like() {
  sudo apt-get update -y
  sudo apt-get install -y curl jq openssh-client
  if ! need_cmd bw; then
    curl -fsSL https://bitwarden.com/install.sh | bash
    if ! need_cmd bw; then
      echo "Bitwarden CLI 'bw' not found after install. Ensure /usr/local/bin is in PATH."
      exit 1
    fi
  fi
}

install_alpine() {
  sudo apk add --no-cache curl jq openssh-client nodejs npm
  if ! need_cmd bw; then
    sudo npm install -g @bitwarden/cli
  fi
}

install_arch() {
  sudo pacman -S --needed --noconfirm curl jq openssh nodejs npm
  if ! need_cmd bw; then
    sudo npm install -g @bitwarden/cli
  fi
}

install_rhel_like() {
  local pkg_mgr
  if need_cmd dnf; then
    pkg_mgr=dnf
  else
    pkg_mgr=yum
  fi
  # EPEL provides nodejs/npm on RHEL/CentOS/Rocky/Alma; not needed on Fedora
  if [[ ! -f /etc/fedora-release ]]; then
    sudo "$pkg_mgr" install -y epel-release
  fi
  sudo "$pkg_mgr" install -y curl jq openssh-clients nodejs npm
  if ! need_cmd bw; then
    sudo npm install -g @bitwarden/cli
  fi
}

detect_and_install() {
  if need_cmd bw && need_cmd jq && need_cmd ssh-keygen; then
    echo "All dependencies already installed, skipping."
    return
  fi

  if [[ -f /etc/alpine-release ]]; then
    install_alpine
  elif [[ -f /etc/arch-release ]]; then
    install_arch
  elif [[ -f /etc/debian_version ]]; then
    install_debian_like
  elif need_cmd dnf || need_cmd yum; then
    install_rhel_like
  else
    echo "Unsupported distro. Install 'bw', 'jq', and 'openssh-client' manually and re-run."
    exit 1
  fi
}

bw_login_unlock() {
  # Reuse existing session if already set in environment
  if [[ -n "${BW_SESSION:-}" ]]; then
    echo "Using existing BW_SESSION from environment."
    export BW_SESSION
    return
  fi

  # Configure server if provided
  if [[ -n "$BW_SERVER" ]]; then
    bw config server "$BW_SERVER" >/dev/null
  fi

  # If NONINTERACTIVE=1, assume user already ran bw login and we can unlock
  if [[ "$NONINTERACTIVE" == "1" ]]; then
    export BW_SESSION
    BW_SESSION="$(bw unlock --raw)"
    return
  fi

  # Check if already logged in; handle fresh install where status may error
  local status
  status="$(bw status 2>/dev/null | jq -r '.status' || echo 'unauthenticated')"
  case "$status" in
    "unauthenticated")
      echo "Bitwarden: not logged in. Starting interactive login..."
      bw login
      ;;
    "locked"|"unlocked")
      ;;
    *)
      echo "Unexpected Bitwarden status: $status"
      ;;
  esac

  # Unlock (prompts for master password or uses biometric if configured)
  export BW_SESSION
  BW_SESSION="$(bw unlock --raw)"
}

find_item_id() {
  # Use --search for speed and less data
  local item_json item_id
  item_json="$(bw list items --search "$KEY_ITEM_NAME" | jq -c ".[] | select(.name==\"$KEY_ITEM_NAME\")" | head -n 1)"
  if [[ -z "$item_json" ]]; then
    echo "Could not find a Bitwarden item named: $KEY_ITEM_NAME"
    echo "Fix by renaming the item or set KEY_ITEM_NAME env var."
    exit 1
  fi
  item_id="$(echo "$item_json" | jq -r '.id')"
  echo "$item_id"
}

ensure_attachment_exists() {
  local item_id="$1"
  local att_names
  att_names="$(bw get item "$item_id" | jq -r '.attachments[]?.fileName' || true)"
  if ! echo "$att_names" | grep -Fxq "$KEY_ATTACHMENT_NAME"; then
    echo "Attachment '$KEY_ATTACHMENT_NAME' not found on item '$KEY_ITEM_NAME'."
    echo "Attachments present:"
    echo "$att_names" | sed 's/^/  - /'
    exit 1
  fi
}

restore_key_from_attachment() {
  local item_id="$1"

  mkdir -p "$(dirname "$SSH_KEY_PATH")"
  chmod 700 "$(dirname "$SSH_KEY_PATH")"

  # Download attachment -> private key file
  bw get attachment "$KEY_ATTACHMENT_NAME" --itemid "$item_id" --output "$SSH_KEY_PATH" >/dev/null

  chmod 600 "$SSH_KEY_PATH"

  # Generate public key from private key (works even if you didn't store the .pub)
  ssh-keygen -y -f "$SSH_KEY_PATH" > "${SSH_KEY_PATH}.pub"
  chmod 644 "${SSH_KEY_PATH}.pub"
}

ensure_ssh_config() {
  # Add/ensure GitHub host block uses this key.
  # We’ll append if no exact "Host github.com" block exists.
  mkdir -p "$(dirname "$SSH_CONFIG_PATH")"
  touch "$SSH_CONFIG_PATH"
  chmod 600 "$SSH_CONFIG_PATH"

  if ! grep -qE '^\s*Host\s+github\.com\s*$' "$SSH_CONFIG_PATH"; then
    cat >> "$SSH_CONFIG_PATH" <<EOF

Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY_PATH
    IdentitiesOnly yes
EOF
  fi
}

test_github() {
  echo
  echo "Testing SSH auth to GitHub..."
  local output rc
  set +e
  output="$(ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1)"
  rc=$?
  set -e
  if echo "$output" | grep -q "successfully authenticated"; then
    echo "SSH auth successful: $output"
  else
    echo "WARNING: SSH auth may have failed (exit $rc): $output"
    echo "If the key has a passphrase, run: ssh-add $SSH_KEY_PATH"
    echo "Then verify the public key is added to GitHub: https://github.com/settings/keys"
  fi
}

main() {
  echo "== Installing prerequisites (bw, jq, ssh) =="
  detect_and_install

  echo "== Bitwarden login/unlock =="
  bw_login_unlock

  echo "== Locating Bitwarden item: $KEY_ITEM_NAME =="
  local item_id
  item_id="$(find_item_id)"
  echo "Found item id: $item_id"

  echo "== Verifying attachment: $KEY_ATTACHMENT_NAME =="
  ensure_attachment_exists "$item_id"

  echo "== Restoring SSH key to: $SSH_KEY_PATH =="
  restore_key_from_attachment "$item_id"

  echo "== Ensuring SSH config uses this key for github.com =="
  ensure_ssh_config

  test_github

  echo
  echo "Done."
  echo "Private key: $SSH_KEY_PATH"
  echo "Public key : ${SSH_KEY_PATH}.pub"
  echo "SSH config : $SSH_CONFIG_PATH"
}

main "$@"