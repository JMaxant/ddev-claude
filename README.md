# ddev-claude

Add-on DDEV qui fournit **Claude Code** dans un service Docker dédié, avec
[RTK (Rust Token Killer)](https://github.com/rtk-ai/rtk) pré-câblé.

## Principes

- **Service dédié** (`docker-compose.claude.yaml`) sans routage HTTP : c'est un
  conteneur outil dans lequel on `exec`. Géré par DDEV comme n'importe quel
  service additionnel (démarrage, arrêt, suppression).
- **Auth partagée entre tous les projets** : les credentials OAuth sont copiés
  depuis `~/.claude.json` (hôte) dans `~/.ddev/claude/` à chaque démarrage.
  Un seul login suffit — pour tous les projets DDEV.
- **RTK câblé automatiquement** à chaque démarrage via l'entrypoint du container.
- **Code projet partagé** : le service voit `/var/www/html` comme le container web
  (même bind-mount).

## Prérequis

| Dépendance | Rôle | Vérification |
|------------|------|--------------|
| [DDEV](https://ddev.com) ≥ v1.24.0 | Orchestration des services | `ddev version` |
| Docker | Runtime des containers | `docker info` |
| [Claude Code](https://claude.ai/code) sur l'hôte | Auth partagée (credentials copiés depuis l'hôte) | `claude --version` |
| `jq` sur l'hôte | Extraction des champs auth depuis `~/.claude.json` dans le hook `pre-start` | `jq --version` |
| Compte Claude authentifié sur l'hôte | Source des credentials | `claude auth status` |
| [ddev-ai-ssh](https://github.com/trebormc/ddev-ai-ssh) | SSH dans le container web pour déléguer drush/composer/php | installé automatiquement |

**Installer les dépendances manquantes :**

```bash
# jq (si absent)
sudo apt install jq          # Debian/Ubuntu
brew install jq              # macOS

# Claude Code (si absent)
curl -fsSL https://claude.ai/install.sh | bash
claude login                 # authentification OAuth
```

## Installation

```bash
ddev add-on get your-org/ddev-claude
ddev restart        # construit l'image et démarre le service
ddev claude         # Claude Code dans le projet
```

## Usage quotidien

```bash
ddev claude            # lance Claude Code (mode interactif)
ddev claude --help
ddev claude -p "..."   # mode non-interactif (scripts, CI)
```

## Authentification

L'add-on partage l'authentification de ta machine hôte. À chaque `ddev restart`,
le hook `pre-start` extrait les champs nécessaires depuis `~/.claude.json` :

- `oauthAccount` — identité du compte
- `hasCompletedOnboarding` — empêche le wizard de se relancer
- `migrationVersion`, `machineID`, etc.

Les credentials OAuth (`~/.claude/.credentials.json`) sont copiés de la même façon.
Tout est stocké dans `~/.ddev/claude/`, monté en tant que `~/.claude` dans le
container.

### Expiration du token OAuth

Le token OAuth dure environ **8 heures**. Quand il expire :

- `ddev claude auth status` retourne `loggedIn: false`
- `ddev claude` en mode interactif affiche un wizard de re-connexion (mais ne peut
  pas compléter le flow OAuth depuis le container — Cloudflare bloque les IPs Docker)

**Solution :**

```bash
# Sur l'hôte, Claude Code rafraîchit automatiquement son token.
# Il suffit de le re-copier dans le container :
ddev restart
```

Le hook `pre-start` copie toujours le token frais depuis `~/.claude/.credentials.json`
de l'hôte. Après `ddev restart`, `ddev claude` fonctionne à nouveau sans
re-authentification.

### Alternative : clé API

```bash
# Dans .ddev/.env.claude (à gitignorer)
ANTHROPIC_API_KEY=sk-ant-...
ddev restart
```

DDEV injecte alors `ANTHROPIC_API_KEY` dans le service — pas d'expiration de token,
idéal pour la CI. ⚠️ Clé Console facturée à l'usage, distincte de l'abonnement.

## Agents, skills et MCP

Deux niveaux :

- **Projet (versionné, partagé en équipe)** — à la racine du repo :
  - agents : `.claude/agents/`
  - skills : `.claude/skills/`
  - serveurs MCP : `.mcp.json`

  Visibles via le bind-mount du code. Tout le monde les a automatiquement.

- **Perso (privé à chaque dev)** — dans `~/.ddev/claude/agents/` et
  `~/.ddev/claude/skills/`. Non versionnés, propres à chacun.

## Permissions

Claude Code tourne avec `--dangerously-skip-permissions` dans le container
(adapté à un environnement isolé). Le mode est figé — ajuste via les settings
Claude Code si besoin :

- **Partagé (versionné)** — `.claude/settings.json` à la racine du repo
- **Perso** — `.ddev/claude/settings.json`

## Commandes PHP, Drush, Composer

Le container Claude n'embarque pas PHP. À la place, les commandes sont déléguées
via SSH au container web DDEV — qui a déjà le bon PHP, Drush et Composer.

Depuis `ddev claude`, utilise `ssh web` directement :

```bash
ssh web ./vendor/bin/drush status
ssh web ./vendor/bin/drush cr
ssh web composer install
ssh web php -r "echo PHP_VERSION;"
ssh web npm run build
ssh -t web bash          # shell interactif sur le container web
```

### ddev-ai-ssh

La délégation SSH repose sur [ddev-ai-ssh](https://github.com/trebormc/ddev-ai-ssh)
(de trebormc), déclaré comme dépendance de l'addon et **installé automatiquement**
avec `ddev add-on get`. Il installe un sshd dans le container web et génère des clés
ed25519 par projet dans `.ddev/.agent-ssh-keys/` (jamais commités, ignorés par git).

## RTK (Rust Token Killer)

RTK est câblé **automatiquement** à chaque démarrage via `entrypoint.sh`.
RTK compresse les sorties des commandes Bash de l'agent. Aucune action manuelle.

```bash
ddev rtk gain             # voir les économies de tokens
ddev rtk gain --history   # historique des commandes
ddev rtk discover         # opportunités manquées dans l'historique Claude Code
```

## Exclure des fichiers du contexte Claude

### `.claudeignore` — réduire le contexte

Claude Code respecte un `.claudeignore` à la racine du projet (syntaxe `.gitignore`).
Les fichiers listés ne sont pas indexés ni inclus automatiquement dans le contexte.

```
# .claudeignore
var/cache/
var/log/
*.sql
web/sites/default/settings.local.php
tests/fixtures/large_dataset.json
```

> **Limite :** `.claudeignore` est un hint à l'agent, pas un contrôle d'accès.
> Le fichier reste physiquement accessible dans le container — une commande Bash
> exécutée par Claude peut encore le lire.

### Masquage filesystem — secrets stricts

Pour les fichiers contenant des credentials qui ne doivent **jamais** atteindre le
contexte (même via une commande indirecte), masque-les au niveau Docker avec un
bind-mount sur `/dev/null` :

```yaml
# .ddev/docker-compose.claude.override.yaml
services:
  claude:
    volumes:
      - "/dev/null:/var/www/html/web/sites/default/settings.local.php:ro"
      - "/dev/null:/var/www/html/.env.local:ro"
```

Le fichier apparaît dans le container comme un fichier vide en lecture seule.
Les autres services DDEV (web, db) ne sont pas affectés.

> **Note :** pas de globs — chaque fichier à masquer doit être listé explicitement.

**Quand choisir quoi :**

| Besoin | Outil |
|--------|-------|
| Ne pas polluer le contexte (cache, logs, fixtures) | `.claudeignore` |
| Cacher des secrets stricts (credentials, tokens) | bind-mount `/dev/null` |

## Désinstallation

```bash
ddev add-on remove claude
# La config partagée n'est pas supprimée automatiquement :
rm -rf ~/.ddev/claude/
```

## Dépannage

| Symptôme | Solution |
|----------|----------|
| Wizard d'auth au démarrage | Vérifie que tu es authentifié sur l'hôte (`claude auth status`), puis `ddev restart` |
| Token expiré en session | `ddev restart` pour copier le token rafraîchi depuis l'hôte |
| Service absent | `ddev restart`, puis `ddev describe` |
| `ddev claude auth status` → loggedIn: false | Fais `claude login` sur l'hôte, puis `ddev restart` |
| RTK entre en conflit avec un skill | Bypasse via `rtk proxy` ou ajoute la commande aux exceptions du hook |
