#!/usr/bin/env bash
#ddev-generated
# Synchronise la config Claude Code de l'hote vers ~/.ddev/claude/ (CLAUDE_CONFIG_DIR
# du container). Execute par le hook pre-start de config.claude.yaml.
set -euo pipefail

DEST=~/.ddev/claude
SRC=~/.claude

mkdir -p "$DEST"

# --- Credentials OAuth ---
cp "$SRC/.credentials.json" "$DEST/.credentials.json" 2>/dev/null \
  || touch "$DEST/.credentials.json"

# --- Etat utilisateur (champs auth/onboarding uniquement) ---
# On exclut les projets, les cles GrowthBook et autres caches specifiques a l'hote.
# hasCompletedOnboarding est le champ cle qui empeche le wizard de s'afficher.
# mcpServers (scope "user") est inclus : contrairement au scope "local"/"project",
# il n'est pas indexe par chemin de projet, donc il reste valide malgre le
# chemin different du container (/var/www/html).
if [ -f ~/.claude.json ]; then
  jq '{
    oauthAccount,
    hasCompletedOnboarding,
    lastOnboardingVersion,
    migrationVersion,
    userID,
    machineID,
    opusProMigrationComplete,
    sonnet1m45MigrationComplete,
    sonnet45MigrationComplete,
    seenNotifications,
    installMethod,
    changelogLastFetched,
    lastReleaseNotesSeen,
    autoUpdates,
    mcpServers
  } | with_entries(select(.value != null))' \
    ~/.claude.json > "$DEST/.claude.json" 2>/dev/null \
  || printf '{}' > "$DEST/.claude.json"
else
  printf '{}' > "$DEST/.claude.json"
fi

# --- Settings (MCPs, permissions, theme, hooks) ---
# L'entrypoint (rtk init --auto-patch) ajoutera le hook RTK sans ecraser le reste.
# Note : les MCPs necessitant npx/uvx/python3 ne fonctionneront pas dans le container
# sans ajout de ces runtimes au Dockerfile.
[ -f "$SRC/settings.json" ] && cp "$SRC/settings.json" "$DEST/settings.json"

# --- Repertoires utilisateur (skills, agents) ---
# cp -rL pour suivre les symlinks (ex: skills pointes vers ~/workspace/ia/skills/).
# Swap atomique : on copie d'abord vers .new pour ne pas detruire l'existant en
# cas d'echec de la copie.
for d in skills agents; do
  [ -d "$SRC/$d" ] || continue
  cp -rL "$SRC/$d" "$DEST/$d.new" \
    && rm -rf "$DEST/$d" \
    && mv "$DEST/$d.new" "$DEST/$d"
done
