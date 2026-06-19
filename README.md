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
ddev restart        # construit l'image et démarre le service
ddev claude-init    # une fois : OAuth + hook RTK + install GSD
```

## Usage quotidien

```bash
ddev claude            # lance Claude Code dans le projet
ddev claude --help
```

La commande reproduit ton sous-répertoire courant à l'intérieur du conteneur :
lancée depuis `web/modules/foo`, Claude démarre au bon endroit.

## Authentification

`ddev claude-init` lance le flux OAuth : une URL s'affiche, tu l'ouvres dans ton
navigateur, tu t'authentifies, tu recolles le code. Le credential est écrit dans
`~/.claude/.credentials.json` (mode 0600) **dans le volume**, donc persistant.
Le refresh token gère ensuite le renouvellement : pas besoin de se reconnecter
à chaque redémarrage.

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

## RTK (Rust Token Killer)

`ddev claude-init` exécute `rtk init -g`, qui installe un hook dans la config
Claude Code du conteneur (persisté dans le volume). RTK compresse alors
automatiquement les sorties des commandes Bash de l'agent. Vérifier les gains :

```bash
ddev exec -s claude rtk gain
```

## GSD (Git. Ship. Done.)

Installé **par projet** via l'installateur officiel (`npx @opengsd/gsd-core@latest`),
lancé par `ddev claude-init`. Choisis le runtime *Claude Code* et l'install *locale*.
Les agents/commands GSD atterrissent dans le projet. Ensuite, dans Claude :
`/gsd-new-project`, etc.

## Désinstallation

```bash
ddev add-on remove claude
# Le volume de config/auth n'est pas supprimé automatiquement :
docker volume rm ddev-<projet>-claude-config
```

## Dépannage

- **`ddev claude` dit "aucune authentification"** → lance `ddev claude-init`.
- **Service absent** → `ddev restart`, puis `ddev describe`.
