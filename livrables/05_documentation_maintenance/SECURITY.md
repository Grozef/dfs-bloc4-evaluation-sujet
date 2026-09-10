Candidat 06 - LISOWSKI François

# Journal de securite

Ce document recense les failles de securite identifiees pendant l'epreuve, leur evaluation et les mesures correctives appliquees.

Session du 10/09/2026. Les heures sont en heure de Paris. Les preuves sont detaillees dans les livrables 02 (exploitation securisee) et 04 (supervision et maintenance). Les identifiants de commit renvoient au depot de l'application.

## Faille 1 — Injection SQL dans la recherche de tickets

| Champ | Description |
| --- | --- |
| Date de detection | 10/09/2026, 09:28 (qualification) |
| Composant concerne | `app/Http/Controllers/Api/TicketController.php`, methode `index`, parametre `search` de `GET /api/v1/tickets` |
| Description de la faille | Terme de recherche concatene dans du SQL brut : `orWhereRaw("reference like '%{$search}%'")`. Une apostrophe provoque une erreur 500 (`SQLSTATE 42000 / 1064`), et une charge construite modifie la requete |
| Severite estimee | `Haute` |
| Impact potentiel | Lecture de toute la base accessible au compte applicatif : utilisateurs et hachages, token API en clair, contacts clients. Prerequis : un token valide, partage avec le microservice |
| Mesure corrective appliquee | Requete reecrite avec le Query Builder et des parametres lies, dans un `where` imbrique (`2f85b24`) |
| Statut | `Corrige` |
| Preuve de correction | `search=%27` renvoie 200 en qualification, en production et en local. `laravel.log` de production sans erreur SQL depuis le deploiement |

## Faille 2 — Droits des tokens API non verifies

| Champ | Description |
| --- | --- |
| Date de detection | 10/09/2026, matin (revue de `EnsureApiTokenIsValid`) |
| Composant concerne | `app/Http/Middleware/EnsureApiTokenIsValid.php`, `routes/api.php` |
| Description de la faille | La colonne `abilities` des tokens n'etait jamais lue : tout token actif pouvait lire, creer et modifier des tickets et appeler l'API meteo |
| Severite estimee | `Moyenne` |
| Impact potentiel | Un token destine a la lecture (tableau de bord) permet de modifier les donnees. Pas de moindre privilege |
| Mesure corrective appliquee | Parametre de droit du middleware, applique route par route : `tickets:read`, `tickets:write`, `weather:read` (`6c944b3`) |
| Statut | `Corrige` |
| Preuve de correction | Token temporaire limite a `tickets:read` : `GET` 200, `PATCH` 403 `Insufficient token ability.`, `external/weather` 403 (Docker, qualification, production) |

## Faille 3 — Webhook `hooks.php` sans signature ni restriction d'origine

| Champ | Description |
| --- | --- |
| Date de detection | 10/09/2026, matin |
| Composant concerne | `public/hooks.php`, `app/Http/Controllers/WebhookController.php`, `config/services.php` |
| Description de la faille | Point d'entree public protege uniquement par HTTP Basic, avec des identifiants de demonstration (`WEBHOOK_BASIC_*`) et un repli codé en dur si la configuration manquait. Aucune signature du contenu, aucune restriction d'origine |
| Severite estimee | `Haute` |
| Impact potentiel | Quiconque connait ou devine les identifiants modifie le statut des tickets et cree des interventions. Contenu rejouable ou alterable en transit. Sans configuration, les identifiants par defaut ouvraient l'acces |
| Mesure corrective appliquee | En-tete `X-OpsTrack-Signature` obligatoire (HMAC-SHA256 du corps, `hash_equals`), liste d'IP ou CIDR optionnelle (`WEBHOOK_ALLOWED_IPS`), refus explicite si les identifiants ou le secret sont vides, secret aleatoire en production et en qualification (`eec0470`) |
| Statut | `Corrige` (liste d'IP vide faute d'emetteur connu, a renseigner) |
| Preuve de correction | Sans signature, signature d'un autre secret ou corps altere : 401. Requete signee : 200. Rejeu : `already processed`. IP hors liste : 403. Configuration vide : 401 (Docker, qualification, production) |

## Faille 4 — Identifiants de demonstration dans le depot

| Champ | Description |
| --- | --- |
| Date de detection | 10/09/2026, matin |
| Composant concerne | `.env.example`, `config/services.php` |
| Description de la faille | `.env.example` contenait les identifiants de la base de qualification, le token API et les identifiants du webhook utilises en qualification |
| Severite estimee | `Moyenne` |
| Impact potentiel | Reutilisation des identifiants sur tout environnement installe sans les changer. Divulgation des acces de qualification |
| Mesure corrective appliquee | Valeurs videes dans `.env.example`, repli `user` / `password` retire (`eec0470`). Production installee avec des secrets generes par `openssl rand` |
| Statut | `Corrige` |
| Preuve de correction | Diff du commit. Verification en production : token et mot de passe du webhook differents des valeurs d'origine. CI : la suite de tests a revele puis valide la dependance du seeder au token (`653f131`) |

## Faille 5 — Production non chiffree et non filtree a la livraison

| Champ | Description |
| --- | --- |
| Date de detection | 10/09/2026, inventaire de la production |
| Composant concerne | Serveur de production : Apache, reseau, systeme |
| Description de la faille | Pas de HTTPS (port 443 ferme), pare-feu inactif, site Apache par defaut, `ServerTokens OS` (version et systeme divulgues) |
| Severite estimee | `Haute` |
| Impact potentiel | Token API, identifiants du webhook et cookies de session transmis en clair. Surface d'attaque non maitrisee |
| Mesure corrective appliquee | Let's Encrypt avec redirection 301 et HSTS, ufw (22, 80, 443), MySQL, MongoDB, Redis et Next.js limites a `127.0.0.1`, `ServerTokens Prod`, `ServerSignature Off`, `TraceEnable Off`, en-tetes `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `APP_DEBUG=false`, `SESSION_SECURE_COOKIE=true` |
| Statut | `Corrige` |
| Preuve de correction | `http://` renvoie 301 vers `https://`. Certificat `CN=eval-dfs-p-tpl-20265-06.it-students.fr` emis par Let's Encrypt, expire le 09/12/2026. Depuis Internet : ports 3000, 3306, 6379, 27017 fermes. En-tetes verifies par `curl -sI` |

## Faille 6 — Attaques SSH par dictionnaire sans protection

| Champ | Description |
| --- | --- |
| Date de detection | 10/09/2026, analyse de `auth.log` |
| Composant concerne | Service SSH des deux serveurs |
| Description de la faille | 266 tentatives depuis `37.140.242.106` (production, 10/09 07:16-07:18) ; 266 depuis `89.238.165.139` et 266 depuis `193.95.2.23` (qualification). Comptes vises : `user`, `debian`, `admin`, `pi`, `ftp`. Aucun bannissement possible (pas de fail2ban), `X11Forwarding yes`, connexion `root` par cle autorisee |
| Severite estimee | `Moyenne` (authentification par mot de passe deja desactivee : aucune tentative n'a abouti) |
| Impact potentiel | Compromission en cas de mot de passe faible reactive ou de cle divulguee. Bruit dans les journaux, charge |
| Mesure corrective appliquee | fail2ban, jail `sshd` (5 echecs en 10 min : 1 h). `PermitRootLogin no`, `X11Forwarding no`. Sonde `ssh_bans` avec alerte |
| Statut | `Mitigation en place` |
| Preuve de correction | `sshd -T` renvoie `permitrootlogin no`, `x11forwarding no` (nouvelle session verifiee). Une tentative invalide volontaire donne `Currently failed: 1` et `[sshd] Found` dans `fail2ban.log` |

## Faille 7 — Supervision de securite aveugle (fail2ban sur Ubuntu 24.04)

| Champ | Description |
| --- | --- |
| Date de detection | 10/09/2026, 12:03, controle apres mise en service |
| Composant concerne | fail2ban, filtre `sshd` en mode journald |
| Description de la faille | Le filtre fourni cherche `_SYSTEMD_UNIT=sshd.service`, alors que sshd journalise sous `ssh.service` : aucune tentative n'etait vue, `Total failed: 0` pendant les attaques |
| Severite estimee | `Moyenne` |
| Impact potentiel | Fausse impression de protection : aucun bannissement, aucune alerte |
| Mesure corrective appliquee | `journalmatch = _SYSTEMD_UNIT=ssh.service + _COMM=sshd` dans la jail versionnee (`9a962ec`) |
| Statut | `Corrige` |
| Preuve de correction | `fail2ban-regex -m '_SYSTEMD_UNIT=ssh.service + _COMM=sshd' systemd-journal sshd` : 272 lignes reconnues. Detection en direct d'une tentative de test |

## Faille 8 — Compte `root` MySQL avec mot de passe par defaut

| Champ | Description |
| --- | --- |
| Date de detection | 10/09/2026, inventaire |
| Composant concerne | MySQL 8.0 (production et qualification) |
| Description de la faille | Compte `root` avec le mot de passe trivial communique dans la fiche d'installation, en `mysql_native_password` |
| Severite estimee | `Moyenne` (MySQL n'ecoute que sur `127.0.0.1`), `Haute` sur la qualification ou phpMyAdmin est public |
| Impact potentiel | Controle total des bases pour tout acces local ou via phpMyAdmin |
| Mesure corrective appliquee | Production : mot de passe aleatoire (`/root/.my.cnf`, 600), application sur un compte dedie limite a sa base |
| Statut | `Corrige` en production. `Identifie, non corrige` en qualification (acces de travail fourni par la fiche) |
| Preuve de correction | Production : l'ancien mot de passe est refuse, `sudo mysql` renvoie `root@localhost` |

## Faille 9 — Qualification exposee (phpMyAdmin public, debug actif, listing)

| Champ | Description |
| --- | --- |
| Date de detection | 10/09/2026, diagnostic de la qualification |
| Composant concerne | Serveur de qualification : `conf-enabled/phpmyadmin.conf`, `.env`, vhost |
| Description de la faille | `/phpmyadmin` accessible depuis Internet, `APP_DEBUG=true` (traces et chemins dans les erreurs), `Options Indexes`, pare-feu inactif a la livraison |
| Severite estimee | `Haute` |
| Impact potentiel | Attaque de l'interface d'administration de la base, divulgation d'informations techniques |
| Mesure corrective appliquee | Appliques sur la qualification : fail2ban, sshd, auditd, en-tetes Apache, logrotate. Configuration applicative et phpMyAdmin conserves par decision, car ce sont les acces de travail fournis par la fiche. Production installee sans phpMyAdmin, avec `APP_DEBUG=false` et `Options -Indexes` |
| Statut | `Identifie, non corrige` (qualification) |
| Preuve de correction | Production : `/phpmyadmin` et `/.env` en 404, page d'erreur sans trace. Qualification : `/phpmyadmin/` repond 200 (constat du 10/09) |

## Faille 10 — Microservice Next.js sur une version vulnerable

| Champ | Description |
| --- | --- |
| Date de detection | 10/09/2026, 12:15. Alerte dans le journal du pipeline, run 2 (`npm warn deprecated next@15.3.1: This version has a security vulnerability`), confirmee par `npm audit` et la base GitHub Advisory |
| Composant concerne | Microservice `dispatch-dashboard` : dependance `next` 15.3.1 (App Router), expose publiquement via `/dispatch-dashboard` |
| Description de la faille | Avis critiques sur `next` 15.3.1 : `GHSA-9qr9-h5gf-34mp` (execution de code a distance via le protocole React Flight, corrige a partir de 15.3.6) et `GHSA-2xp9-vwfh-vxw4` (execution de code a distance via l'optimisation d'images AVIF, corrige en 15.5.24). S'y ajoutent plusieurs avis de severite haute : deni de service sur les Server Components, SSRF, contournement de middleware. `npm audit` : `3 vulnerabilities (2 high, 1 critical)` |
| Severite estimee | `Critique` |
| Impact potentiel | Execution de code a distance sur la production sous l'utilisateur du service (`ubuntu`, qui dispose de `sudo`) : compromission complete du serveur, des secrets et des donnees |
| Mesure corrective appliquee | Montee de version vers `next` 15.5.25 (derniere version de la branche 15, qui corrige les avis critiques), commit `80410fb`. Validation d'abord hors production (build Docker `node:20-alpine`, routes identiques), puis deploiement par le pipeline (run 3) : tests, build CI, `npm install` et `next build` sur la qualification puis la production, redemarrage du service, smoke tests |
| Statut | `Corrige` pour les avis critiques. Residuel sur les serveurs (`npm audit --omit=dev`, lockfile reel) : production `3 vulnerabilities (1 moderate, 2 high)`, qualification `4 vulnerabilities (1 moderate, 3 high)`, sans avis critique. Concernes : `postcss` (compilation CSS, correctif impose Next 16) et `sharp` / libvips (`GHSA-f88m-g3jw-g9cj`, optimisation d'images, non utilisee par le microservice). A traiter lors du passage a Next 16 |
| Preuve de correction | Run 3 du 10/09 : `Deploiement 653f131 -> 80410fb`, `▲ Next.js 15.5.25`, `Deploiement reussi : 80410fb` en qualification (13:20) et en production (13:21), tous les smoke tests `OK`. Sur les deux serveurs, `node_modules/next/package.json` indique 15.5.25, et la supervision affiche `INC-240301 INC-240302` |
