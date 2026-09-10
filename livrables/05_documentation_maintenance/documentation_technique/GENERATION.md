Candidat 06 - LISOWSKI François

# Documentation technique generee

Reference HTML des classes, fichiers et routes de l'application OpsTrack, generee avec phpDocumentor 3 a partir du code source uniquement (hors `vendor/` et `node_modules/`).

Point d'entree : `index.html`.

Perimetre analyse :
- `app/` : controleurs, middleware, requetes de validation, ressources API, modeles MySQL et MongoDB, services ;
- `routes/` : `web.php`, `api.php`, `console.php` ;
- `database/` : migrations, factories, seeder ;
- `public/` : `index.php` et le webhook `hooks.php`.

Contenu : 22 classes documentees, 36 fichiers, graphe des classes (`graphs/classes.html`) et rapports (`reports/`).

Commande de generation, reproductible, lancee depuis la racine du depot applicatif (Docker requis, image officielle) :

```bash
docker run --rm -w /data -v "$PWD:/data" -v "$PWD/docs/technique:/out" phpdoc/phpdoc:3 \
  run -d app -d routes -d database -d public -t /out \
  --title "OpsTrack - documentation technique" --cache-folder /tmp/phpdoc-cache
```

Generee le 10/09/2026, sur le commit `653f131` de la branche `main`. A regenerer apres toute modification de classe ou de signature.

Le microservice Next.js (`microservices/dispatch-dashboard`) compte trois fichiers (`app/layout.tsx`, `app/page.tsx`, `lib/api.ts`). Il est decrit dans `base_connaissances.md` et `documentation_api.md` (consommation de `GET /api/v1/tickets`).
