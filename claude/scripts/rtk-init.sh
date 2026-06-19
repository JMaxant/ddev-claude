#!/usr/bin/env bash
#ddev-generated
# Cable le hook RTK dans Claude Code, de maniere idempotente et non-interactive.
# Lance par le hook post-start de DDEV (cf. config.claude.yaml), donc APRES que
# le volume ~/.claude est monte -> le hook ecrit bien dans le volume persistant.
set -eu

# Deja initialise ? On evite de re-tourner a chaque `ddev start`.
if rtk init --show 2>/dev/null | grep -qi "hook:.*up to date\|hook:.*installed\|✅"; then
  exit 0
fi

# Piege connu (rtk >= 0.36.0, issue rtk-ai/rtk#1307) : meme avec --auto-patch,
# `rtk init` ouvre un SECOND prompt (consentement telemetrie) qui bloque sur stdin
# en environnement non-interactif. RTK_TELEMETRY_DISABLED=1 ne supprime PAS ce
# prompt (il coupe seulement l'envoi APRES consentement).
# Parade : le hook est ecrit AVANT le prompt -> on laisse rtk faire son travail,
# on lui ferme stdin (EOF immediat) et on le borne par un timeout qui le tue
# quand il se met a attendre. Le hook reste correctement installe.
RTK_TELEMETRY_DISABLED=1 timeout 15 rtk init -g --auto-patch </dev/null >/dev/null 2>&1 || true

rtk telemetry disable >/dev/null 2>&1 || true