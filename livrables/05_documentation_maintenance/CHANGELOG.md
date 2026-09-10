Candidat 06 - LISOWSKI François

# Changelog

Toutes les modifications notables apportees pendant l'epreuve sont documentees dans ce fichier.

Le format s'inspire de [Keep a Changelog](https://keepachangelog.com/). Les identifiants sont ceux des commits du depot de l'application (branche `main`, base : `61096fb`, depot remis).

## [Session du 10 septembre 2026]

### Ajoute

- `ops/provision.sh` : durcissement et supervision idempotents (fail2ban, sshd, auditd, en-tetes Apache, logrotate, timers systemd) (`c1a16ad`).
- `ops/healthcheck.sh` et `opstrack-healthcheck.timer` : 8 sondes toutes les 5 minutes, alertes ntfy sur changement d'etat (`c1a16ad`).
- `ops/backup.sh`, `ops/restore.sh` et `opstrack-backup.timer` : sauvegarde quotidienne MySQL, MongoDB et configuration, empreintes SHA-256, retention 7 jours, copie hors machine ; restauration verifiee (`c1a16ad`).
- `ops/deploy.sh`, `ops/smoke.sh` et `.github/workflows/deploy.yml` : pipeline GitHub Actions declenche a la main (controles qualite, qualification, production, smoke tests, rollback, alerte d'echec) (`c1a16ad`).
- Environnement Docker Compose local : PHP 8.4 + ext-mongodb, MySQL 8.4, MongoDB 8, microservice Next.js (`d9b8eb5`).
- Webhook : signature HMAC-SHA256 obligatoire (`X-OpsTrack-Signature`) et liste d'IP autorisees optionnelle (`WEBHOOK_SIGNING_SECRET`, `WEBHOOK_ALLOWED_IPS`) (`eec0470`).
- Infrastructure de production : vhosts HTTP et HTTPS, certificat Let's Encrypt avec renouvellement automatique, service systemd du microservice, pare-feu ufw.
- Token API dedie a la suite de tests (`phpunit.xml`) (`653f131`).

### Modifie

- Middleware `api.token` : parametre de droit par route (`api.token:tickets:read`, `tickets:write`, `weather:read`) (`6c944b3`).
- `.env.example` : identifiants de demonstration retires. `config/services.php` : plus de valeurs de repli `user` / `password` pour le webhook (`eec0470`).
- `.gitignore` : fichiers d'outillage local exclus (`6610958`).
- Vhost de production : proxy `/_next/` vers le microservice, `Options -Indexes`, `ServerTokens Prod`, en-tetes de securite et HSTS.
- Production : `APP_ENV=production`, `APP_DEBUG=false`, `LOG_LEVEL=warning`, caches Laravel, secrets aleatoires.
- Microservice : `next` 15.3.1 remplace par 15.5.25 (`80410fb`), deploye par le pipeline en qualification et en production.

### Corrige

- Recherche de tickets : conditions `title` / `reference` groupees, le filtre de priorite s'applique au resultat (`2f85b24`).
- Tableau de bord : cache des indicateurs invalide a chaque creation, modification ou suppression de ticket (`962a52a`).
- `hooks.php` : initialisation du noyau Laravel, fin de l'erreur 500 `Class "config" does not exist` (`97ab8eb`).
- Webhook : statut recu reellement applique au ticket, intervention non dupliquee pour un meme `external_event_id` (`3ae08f9`).
- Microservice de supervision : lecture de `payload.data`, les tickets s'affichent (`c248697`).
- Migrations : `interventions` executee apres `tickets` (erreur MySQL 1824 sur base vide) (`bcf412e`).
- Assets Next.js en 404 derriere Apache (vhost de production).
- fail2ban : correspondance du journal avec l'unite `ssh.service` d'Ubuntu 24.04, les tentatives SSH sont desormais detectees (`9a962ec`).

### Securite

- Injection SQL dans `GET /api/v1/tickets?search=` supprimee (requete parametree) (`2f85b24`).
- Droits des tokens API verifies (403 sur droit insuffisant) (`6c944b3`).
- Webhook authentifie par signature en plus de HTTP Basic, refus si la configuration est absente (`eec0470`).
- Identifiants de demonstration retires du depot (`eec0470`).
- Production : HTTPS + HSTS, pare-feu (22, 80, 443), services de donnees limites a la boucle locale, compte MySQL applicatif dedie, mot de passe `root` MySQL remplace, `APP_DEBUG=false`, phpMyAdmin non installe.
- SSH : `PermitRootLogin no`, `X11Forwarding no`, fail2ban. Audit des fichiers sensibles (auditd).
- Next.js : avis critiques d'execution de code a distance (`GHSA-9qr9-h5gf-34mp`, `GHSA-2xp9-vwfh-vxw4`) corriges par la montee en 15.5.25 (`80410fb`).
- Detail et evaluation de chaque faille : `SECURITY.md`.
