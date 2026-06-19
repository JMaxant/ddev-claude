# ddev-claude

Add-on DDEV qui fournit **Claude Code** dans un service Docker dédié, avec
[RTK (Rust Token Killer)](https://github.com/rtk-ai/rtk) pré-câblé et
[GSD (Git. Ship. Done.)](https://github.com/open-gsd/gsd-core) installable par projet.

## Principes

- **Service dédié par projet** (`docker-compose.claude.yaml`), sans routage HTTP :
  c'est un conteneur outil dans lequel on `exec`. Géré par DDEV (démarrage, arrêt,
  suppression) comme n'importe quel service additionnel.
- **Auth et config persistées par projet** dans un volume nommé
  `ddev-<projet>-claude-config` monté sur `~/.claude`. Survit aux `ddev restart/stop`.
- **Authentification OAuth** (abonnement Claude.ai/Pro/Max) par défaut.
- **Code projet partagé** : le service voit `/var/www/html` exactement comme le
  conteneur web (même bind-mount), donc `.git`, sources, etc.

## Installation

```bash
ddev add-on get your-org/ddev-claude
ddev restart        # construit l'image, démarre le service, câble RTK
ddev claude         # au 1er lancement : /login pour t'authentifier
```

## Usage quotidien

```bash
ddev claude            # lance Claude Code dans le projet
ddev claude --help
```

La commande reproduit ton sous-répertoire courant à l'intérieur du conteneur :
lancée depuis `web/modules/foo`, Claude démarre au bon endroit.

## Authentification

Au premier `ddev claude`, la TUI Claude Code s'ouvre : tape `/login` et suis le
flux OAuth (une URL à ouvrir dans ton navigateur). Le credential est écrit dans
`~/.claude/.credentials.json` (mode 0600) **dans le volume**, donc persistant.
Le refresh token gère ensuite le renouvellement : pas besoin de se reconnecter
à chaque redémarrage.

> `CLAUDE_CONFIG_DIR` est pointé sur `~/.claude` (le volume), donc **toute** la
> config — credential, `.claude.json`, sessions, MCP globaux — y est centralisée
> et persiste à travers `ddev poweroff`, `restart` et reboots.

> Universel Linux/macOS/Windows : comme l'auth se fait *dans le conteneur*, le
> stockage des credentials de ta machine hôte (Keychain macOS, Credential Manager
> Windows, fichier Linux) n'intervient pas. Le conteneur a son propre `~/.claude`.

### Alternative : clé API (CI, ou si OAuth pose souci)

```bash
ddev dotenv set .ddev/.env.claude --anthropic-api-key="sk-ant-..."
ddev restart
```

DDEV injecte alors `ANTHROPIC_API_KEY` dans le service. ⚠️ C'est une clé Console
facturée à l'usage, distincte de ton abonnement. Pense à gitignorer `.ddev/.env.claude`.

## Agents, skills et MCP

Deux niveaux, qui tombent naturellement avec l'architecture :

- **Projet (versionné, partagé en équipe)** — place-les à la racine du repo :
  - agents : `.claude/agents/`
  - skills : `.claude/skills/`
  - serveurs MCP : `.mcp.json`

  Visibles via le bind-mount du code. Tout le monde les a automatiquement,
  identiques, et ils suivent le repo. **Recommandé** pour ce qui est propre au projet.

- **Perso (privé à chaque dev)** — vivent dans `~/.claude` (le volume) :
  `~/.claude/agents/`, `~/.claude/skills/`. Non versionnés, propres à chacun.

## Permissions de Claude Code

L'add-on ne fige **aucune** politique de permissions : Claude Code reste sur son
défaut natif (`default`, qui demande confirmation avant chaque action). Tu règles
le mode où tu veux, modifiable à chaud sans rebuild :

- **Perso (par dev, non versionné)** — `~/.claude/settings.json` dans le conteneur
  (persisté dans le volume). Pour le modifier :
  ```bash
  ddev exec -s claude sh -c 'cat > ~/.claude/settings.json' <<'JSON'
  { "permissions": { "defaultMode": "acceptEdits" } }
  JSON
  ```
- **Partagé (par projet, versionné)** — `.claude/settings.json` à la racine du repo.
  Tout le monde hérite du même réglage ; visible via le bind-mount du code.

Modes disponibles : `default` (demande tout, défaut natif), `acceptEdits`
(auto-approuve les éditions de fichiers, demande pour le shell), `auto`
(classifieur), `bypassPermissions` (aucune invite).

> ⚠️ Attention à `bypassPermissions` : le conteneur monte ton vrai code
> (`/var/www/html`, avec le `.git`). L'isolation Docker ne protège pas le code
> monté — en mode bypass, l'agent peut modifier/supprimer des fichiers et lancer
> des commandes git sans confirmation. `acceptEdits` est un compromis plus sûr.

## RTK (Rust Token Killer)

RTK est câblé **automatiquement** à chaque `ddev start` : un hook DDEV `post-start`
lance `rtk init -g` (mode non-interactif) dans le conteneur, de façon idempotente.
RTK compresse alors les sorties des commandes Bash de l'agent. Aucune action
manuelle. Vérifier les gains :

```bash
ddev exec -s claude rtk gain
```

> ⚠️ Le binaire est installé depuis `rtk-ai/rtk` (le bon projet). On évite
> volontairement `cargo install rtk` à cause d'une collision de nom sur crates.io.
>
> Le câblage contourne aussi un prompt de consentement télémétrie qui bloque en
> mode non-interactif (cf. `claude/scripts/rtk-autoinit.sh`). La télémétrie est
> désactivée.

## GSD (Git. Ship. Done.)

WIP.

## Désinstallation

```bash
ddev add-on remove claude
# Le volume de config/auth n'est pas supprimé automatiquement :
docker volume rm ddev-<projet>-claude-config
```

## Dépannage

- **`ddev claude` dit "pas encore authentifié"** → dans la TUI, tape `/login`.
- **Service absent** → `ddev restart`, puis `ddev describe`.
- **Windows** : l'interactivité de `docker exec -it` (flux OAuth) est la plus
  fiable sous WSL2 ou Git Bash. En PowerShell natif, certains terminaux gèrent
  mal le `-it` ; privilégie WSL2.
- **RTK entre en conflit avec un skill** → bypasse ponctuellement via `rtk proxy`
  ou ajoute la commande aux exceptions du hook.