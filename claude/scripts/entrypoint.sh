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

exec "$@"
