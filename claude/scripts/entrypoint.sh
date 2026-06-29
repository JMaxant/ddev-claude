#!/usr/bin/env bash
#ddev-generated
# Entrypoint du container claude.
# Tourne UNE FOIS au demarrage du container (avant sleep infinity).
# Prepare l'environnement Claude Code puis cede la main a CMD via exec "$@".
set -eu

# --- 1. Hook RTK ---
# settings.json est ephemere (non monte) -> on le reinjecte a chaque demarrage.
# Piege connu (rtk >= 0.36.0) : rtk init ouvre un prompt telemetrie qui bloque
# stdin en mode non-interactif. On ferme stdin et on borne par un timeout.
RTK_TELEMETRY_DISABLED=1 timeout 15 rtk init -g --auto-patch </dev/null >/dev/null 2>&1 || true
rtk telemetry disable >/dev/null 2>&1 || true

# --- 2. Pre-accepte le trust dialog ---
# ~/.claude.json est bind-monte depuis ~/.ddev/claude/.claude.json (rw).
# cp au lieu de mv/rename : les bind-mounts fichier rejettent les renames (EXDEV).
CLAUDE_JSON="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}/.claude.json"
if [ -f "${CLAUDE_JSON}" ] && jq -e 'type == "object"' "${CLAUDE_JSON}" >/dev/null 2>&1; then
  jq '. + {"hasTrustDialogAccepted": true}' "${CLAUDE_JSON}" > /tmp/.claude_state.tmp \
    && cp /tmp/.claude_state.tmp "${CLAUDE_JSON}" \
    && rm -f /tmp/.claude_state.tmp \
    || true
fi

# --- 3. Setup SSH client (delegation vers container web) ---
# La cle privee est generee par ddev-ai-ssh dans .ddev/.agent-ssh-keys/.
# Le container web ecrit son username dans web-user au demarrage (on attend max 15s).
SSH_DIR="${HOME}/.ssh"
mkdir -p "${SSH_DIR}" && chmod 700 "${SSH_DIR}"
cp /tmp/ssh-config "${SSH_DIR}/config" && chmod 600 "${SSH_DIR}/config"

KEY_SRC="/var/www/html/.ddev/.agent-ssh-keys/id_ed25519"
if [ -f "${KEY_SRC}" ]; then
  cp "${KEY_SRC}" "${SSH_DIR}/ddev_agent_key"
  chmod 600 "${SSH_DIR}/ddev_agent_key"

  WEB_USER_FILE="/var/www/html/.ddev/.agent-ssh-keys/web-user"
  for i in $(seq 1 15); do
    [ -f "${WEB_USER_FILE}" ] && break
    sleep 1
  done
  WEB_USER=$(cat "${WEB_USER_FILE}" 2>/dev/null || echo "www-data")
  sed -i "/^Host web$/a\\    User ${WEB_USER}" "${SSH_DIR}/config"
fi

# --- 4. Wrappers bash pour delegation vers container web ---
# Injecte une seule fois (idempotent) dans .bashrc.
BASHRC="${HOME}/.bashrc"
if ! grep -q 'ssh-cmd()' "${BASHRC}" 2>/dev/null; then
  cat >> "${BASHRC}" << 'BASHRC_EOF'

# Delegation SSH vers le container web DDEV (drush, composer, php, etc.)
ssh-cmd() {
  local host="$1"; shift
  local cmd=""
  for arg in "$@"; do cmd="${cmd:+$cmd }$(printf "%q" "$arg")"; done
  ssh "$host" "$cmd"
}
drush()    { ssh-cmd web ./vendor/bin/drush "$@"; }
composer() { ssh-cmd web composer "$@"; }
phpunit()  { ssh-cmd web ./vendor/bin/phpunit "$@"; }
phpstan()  { ssh-cmd web ./vendor/bin/phpstan "$@"; }
php()      { ssh-cmd web php "$@"; }
web-exec() { ssh-cmd web "$@"; }
web-shell(){ ssh -t web bash; }
BASHRC_EOF
fi

exec "$@"
