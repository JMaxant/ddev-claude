# ddev-generated
# Image outil pour Claude Code + RTK (Rust Token Killer).
# GSD (git ship done) n'est PAS installé dans l'image : il s'installe par projet
# via `npx @opengsd/gsd-core` (cf. commande `ddev claude-init`), donc on a juste
# besoin de Node/npx, déjà présents.

FROM node:22-bookworm-slim

# Outils de base : git pour GSD/RTK, curl pour le script d'install RTK,
# ca-certificates pour TLS, ripgrep parce que Claude Code l'utilise abondamment.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       git \
       curl \
       ca-certificates \
       ripgrep \
       less \
  && rm -rf /var/lib/apt/lists/*

# Claude Code (CLI) en global.
RUN npm install -g @anthropic-ai/claude-code

# RTK (Rust Token Killer) — binaire pré-compilé via le script d'install officiel.
# IMPORTANT : on passe par rtk-ai/rtk explicitement. NE PAS faire `cargo install rtk`
# (collision de nom avec "Rust Type Kit" sur crates.io).
# Le script détecte l'archi et pose le binaire dans /usr/local/bin (ou ~/.local/bin).
RUN curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh \
      | sh \
  && (command -v rtk >/dev/null 2>&1 \
      || cp "$HOME/.local/bin/rtk" /usr/local/bin/rtk 2>/dev/null \
      || true) \
  && rtk --version

# Utilisateur non-root aligné sur l'UID/GID DDEV (1000 par défaut côté hôte Linux).
# DDEV réécrit l'utilisateur au runtime via `user:` dans le compose ; on prépare
# néanmoins un home propre pour /home/claude.
RUN useradd --create-home --uid 1000 --shell /bin/bash claude \
  && mkdir -p /home/claude/.claude \
  && chown -R claude:claude /home/claude

# Le code projet est monté ici par DDEV (même bind-mount que le conteneur web).
WORKDIR /var/www/html

# Le conteneur reste vivant : on n'exécute claude qu'à la demande via `docker exec`.
CMD ["tail", "-f", "/dev/null"]
