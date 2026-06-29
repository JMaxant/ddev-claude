# Environnement DDEV + Claude

## Exécution de commandes PHP / Drush / Composer

Ce container ne dispose pas de PHP. Les commandes sont déléguées via SSH au
container web DDEV, qui possède le bon PHP, Drush et Composer du projet.

SSH est pré-configuré (`~/.ssh/config`, `Host web`). Utilise directement :

```bash
ssh web ./vendor/bin/drush <commande>   # Drush
ssh web composer <commande>             # Composer
ssh web php <arguments>                 # PHP CLI
ssh web npm <arguments>                 # NPM
ssh -t web bash                         # Shell interactif sur le container web
```

Pour toute commande nécessitant PHP ou les outils du projet, préfixe-la avec
`ssh web`.
