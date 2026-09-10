Candidat 06 - LISOWSKI François

# Supervision, journalisation, sauvegarde et maintenance corrective

> Competence evaluee : `C32` — Mettre en oeuvre un systeme de supervision pour detecter, diagnostiquer et corriger bugs, incidents et failles.

Session du 10 septembre 2026. Les sorties citees ont ete relevees sur la production (`eval-dfs-p-tpl-20265-06.it-students.fr`) et la qualification (`eval-dfs-q-tpl-20265-06.it-students.fr`). Scripts et configurations en annexe (`livrables/annexes/04/`).

## 1. Journalisation

### 1.1 Services journalises

| Service | Emplacement des journaux | Niveau de detail |
| --- | --- | --- |
| Apache (application et proxy Next.js) | `/var/log/apache2/opstrack_access.log`, `opstrack_error.log` | Format `combined` : IP source, date, methode, URL, code, taille, referer, user-agent. Erreurs PHP fatales dans `opstrack_error.log` |
| Laravel | `/var/www/opstrack/storage/logs/laravel.log` | `LOG_LEVEL=warning` en production (`debug` en qualification), exceptions avec contexte |
| Journal applicatif | MongoDB, base `opstrack_logs`, collection `event_logs` | Un document par evenement metier : `channel` (`api`, `webhook`, `integration`), `event_type` (`tickets.index`, `ticket.created`, `ticket.updated`, `intervention.synced`, `weather.synced`), `severity`, `payload` (filtres, changements, charge du webhook), `recorded_at` |
| Microservice Next.js | journald, unite `opstrack-dispatch-dashboard` | sortie standard du serveur Next |
| MySQL / MongoDB | `/var/log/mysql/error.log`, `/var/log/mongodb/mongod.log` | erreurs et demarrages des serveurs |
| SSH et sudo | `/var/log/auth.log`, journald (`ssh.service`) | tentatives, connexions acceptees (cle, IP), commandes `sudo` |
| fail2ban | `/var/log/fail2ban.log` | detections et bannissements |
| auditd | `/var/log/audit/audit.log` | acces en ecriture aux fichiers sensibles (cles `opstrack-*`) |
| Sondes | journald, tag `opstrack-healthcheck` | etat de chaque sonde toutes les 5 minutes |
| Sauvegardes | journald, unite `opstrack-backup` | debut, fin, dossier produit, erreurs |
| Deploiements | journaux des runs GitHub Actions | chaque etape du pipeline (livrable 03) |

### 1.2 Configuration de la journalisation

Configuration en place :
- Production : `LOG_CHANNEL=stack`, `LOG_STACK=single`, `LOG_LEVEL=warning`. Seuls les avertissements et erreurs sont conserves, sans donnees de debogage.
- Rotation des journaux Laravel : `/etc/logrotate.d/opstrack` (quotidien, 14 fichiers, compression, `copytruncate`, `su ubuntu www-data`). Verifie par `logrotate -d` : `rotating pattern: /var/www/opstrack/storage/logs/*.log after 1 days (14 rotations)`. Les journaux Apache, MySQL, fail2ban et ufw suivent les rotations fournies par Ubuntu.
- Journal applicatif MongoDB : ecrit par `App\Services\EventLogService`. En cas d'indisponibilite de MongoDB, un avertissement `MongoDB logging unavailable.` part dans `laravel.log`, et la requete metier n'est pas bloquee.
- Le modele `App\Models\Mongo\EventLog` declare `$collection = 'app_events'`, mais `mongodb/laravel-mongodb` 5.x lit `$table` : les documents sont ecrits dans `event_logs`. C'est la collection a interroger.

Exploitation :

```bash
# 20 derniers evenements metier
mongosh opstrack_logs --eval 'db.event_logs.find().sort({recorded_at:-1}).limit(20)'
# evenements webhook d'un ticket
mongosh opstrack_logs --eval 'db.event_logs.find({channel:"webhook","payload.payload.ticket_reference":"INC-240302"})'
# erreurs applicatives
grep '\.ERROR' /var/www/opstrack/storage/logs/laravel.log | tail
# etat des sondes
journalctl -t opstrack-healthcheck --since today
```

## 2. Outils et configurations d'audit

| Outil | Configuration | Usage |
| --- | --- | --- |
| auditd | 12 regles `ops/audit/opstrack.rules` : ecriture sur `.env`, `.env.local`, `/etc/opstrack`, `sudoers`, `authorized_keys`, configuration sshd, vhosts Apache, `public/`, `/etc/ufw` | `ausearch -k opstrack-secrets -i`, `aureport -f` |
| fail2ban | jail `sshd`, filtre journald corrige pour Ubuntu 24.04 (section 7.3) | `fail2ban-client status sshd` |
| `fail2ban-regex` | filtre `sshd` rejoue sur l'historique | mesurer une attaque passee : `fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf` |
| Controles de configuration | `sshd -T`, `ufw status verbose`, `ss -tlnp`, `apache2ctl -S`, `php artisan about` | verifier la conformite apres chaque intervention |
| Analyse des acces | `awk`/`grep` sur les access logs Apache et `auth.log` | identifier les sources d'appels (section 7.1) |
| Tests fonctionnels et de securite | `ops/smoke.sh`, scripts de verification curl + SQL (livrable 03) | apres chaque deploiement |

Etat audite en production (10/09) :
- `sshd -T` : `passwordauthentication no`, `permitrootlogin no`, `x11forwarding no` ;
- `ufw` : seuls 22, 80 et 443/tcp ouverts ;
- `php artisan about` : `Environment production`, `Debug Mode OFF` ;
- `auditctl -l` : 12 regles chargees.

## 3. Supervision et alertes

### 3.1 Sondes mises en place

Script `ops/healthcheck.sh`, lance par `opstrack-healthcheck.timer` toutes les 5 minutes sur la production et la qualification :

| Sonde | Cible | Seuil ou condition | Action en cas d'alerte |
| --- | --- | --- | --- |
| `http_health` | `GET <BASE_URL>/api/health` | code HTTP different de 200 | notification ntfy priorite haute, puis diagnostic Apache/PHP (`opstrack_error.log`, `laravel.log`) |
| `dashboard` | `GET <BASE_URL>/dispatch-dashboard` | aucune reference `INC-` dans la page | verifier le service Next, le token API et `api.ts` |
| `services` | apache2, mysql, mongod, redis-server, opstrack-dispatch-dashboard, fail2ban (+ `certbot.timer` en production) | un service inactif | `systemctl status`, `journalctl -u`, redemarrage |
| `disk` | systeme de fichiers `/` | occupation de 85 % ou plus | nettoyage des caches et journaux, extension du volume |
| `certificate` (production) | certificat servi sur le port 443 | expiration dans moins de 14 jours | `certbot renew`, verifier `certbot.timer` |
| `laravel_errors` | `storage/logs/laravel.log` | nouvelle(s) ligne(s) `ERROR` depuis le passage precedent | lire la trace, qualifier bug ou incident |
| `ssh_bans` | `fail2ban-client status sshd` | nouvelle(s) IP bannie(s) | analyser la source (section 7.1), bloquer durablement si recidive |
| `backup_age` (production) | `/var/backups/opstrack` | aucune sauvegarde, ou derniere sauvegarde de plus de 26 h | `journalctl -u opstrack-backup`, relancer la sauvegarde |

En complement, le pipeline de deploiement envoie une notification si un run echoue (livrable 03).

### 3.2 Mecanisme d'alerte

Principe :
- Chaque resultat est ecrit dans le journal (`logger -t opstrack-healthcheck`).
- L'etat precedent de chaque sonde est memorise (`/var/lib/opstrack-healthcheck`). Une notification part UNIQUEMENT au changement d'etat : `ALERTE <sonde> : <detail>` quand elle echoue, `RETABLI <sonde>` au retour a la normale. Pas de repetition toutes les 5 minutes.
- Canal : push HTTP vers un topic ntfy.sh prive, recu en application mobile ou navigateur. Le topic est un secret aleatoire, stocke dans `/etc/opstrack/healthcheck.env` (600) et dans les secrets GitHub, jamais versionne. Les messages ne contiennent aucune donnee sensible.

Preuves recues sur le topic (heure de Paris, le 10/09) :

```
12:00:47 | OpsTrack ip-172-31-34-120 | ALERTE backup_age : aucune sauvegarde      (mise en service des sondes en production)
12:02:16 | OpsTrack ip-172-31-34-120 | RETABLI backup_age                         (apres la premiere sauvegarde)
```

Une panne a aussi ete simulee sur la qualification (arret du service Next.js) : voir la section 7.4.

## 4. Strategie de sauvegarde et restauration

### 4.1 Elements sauvegardes

| Element | Methode | Frequence | Retention |
| --- | --- | --- | --- |
| Base MySQL `opstrack` (tickets, interventions, utilisateurs, tokens, sessions, cache) | `mysqldump --single-transaction --no-tablespaces`, compresse (`mysql.sql.gz`) | quotidienne 02:30 (`opstrack-backup.timer`, `Persistent=true`) | 7 jours sur la production |
| Base MongoDB `opstrack_logs` (journal applicatif) | `mongodump --archive --gzip` (`mongodb.archive.gz`) | quotidienne | 7 jours sur la production |
| Configuration : `.env`, `.env.local`, vhosts Apache, unite Next.js, `/etc/letsencrypt`, `/etc/opstrack` | `tar czf` (`config.tar.gz`) | quotidienne | 7 jours sur la production |
| Integrite | `SHA256SUMS` du dossier, verifie avant toute restauration | a chaque sauvegarde | idem |
| Copie hors machine | `rsync` SSH vers la qualification (`/var/backups/opstrack-prod`), cle dediee restreinte en ecriture seule (`rrsync -wo`) | a chaque sauvegarde | conservee sur la qualification (volume de 24 Ko par jour) |

Non sauvegardes :
- le code, versionne dans Git et redeployable par le pipeline ;
- Redis : ni cache ni session n'y sont stockes (`CACHE_STORE=database`, `SESSION_DRIVER=database`).

Objectifs : RPO de 24 h. RTO d'environ 30 minutes pour une restauration sur un serveur deja installe (livrable 02, section 5).

Premiere sauvegarde executee et verifiee en production :

```
$ sudo systemctl start opstrack-backup.service   -> result=success
Sauvegarde terminee : /var/backups/opstrack/20260910-120214
-rw-r--r-- 1 root root   244 SHA256SUMS
-rw-r--r-- 1 root root 12780 config.tar.gz
-rw-r--r-- 1 root root  1454 mongodb.archive.gz
-rw-r--r-- 1 root root  9623 mysql.sql.gz
config.tar.gz: OK   mongodb.archive.gz: OK   mysql.sql.gz: OK
```

Copie recue sur la qualification : `/var/backups/opstrack-prod/20260910-120214/`, avec les 4 memes fichiers et les memes tailles.

### 4.2 Procedure de restauration

Script `ops/restore.sh <dossier> <base_mysql> <base_mongo> [base_mongo_source]` :
1. verification des empreintes (`sha256sum -c SHA256SUMS`), arret si une archive est alteree ;
2. creation de la base MySQL cible (utf8mb4), puis import de `mysql.sql.gz` ;
3. `mongorestore --drop --gzip --archive` avec renommage d'espace de noms (`--nsFrom opstrack_logs.* --nsTo <cible>.*`) ;
4. pour une restauration de production : cible `opstrack` et `opstrack_logs`, extraction de `config.tar.gz` si le serveur est reconstruit, puis `php artisan config:cache` et `sudo systemctl restart opstrack-dispatch-dashboard`, et enfin `ops/smoke.sh`.

Validation effectuee SUR LA QUALIFICATION, comme l'autorise le sujet : aucune restauration destructive n'a ete faite sur la production. La sauvegarde de production du 10/09 12:02:14, copiee sur la qualification, a ete restauree dans des bases de test isolees (`opstrack_restore_test`, `opstrack_logs_restore`) :

```
12:04:11
config.tar.gz: OK
mongodb.archive.gz: OK
mysql.sql.gz: OK
Restauration terminee : MySQL opstrack_restore_test, MongoDB opstrack_logs_restore
```

| Donnee | Production au moment de la sauvegarde | Restaure sur la qualification |
| --- | --- | --- |
| users | 3 | 3 |
| tickets | 2 (`INC-240301` critical/in_progress, `INC-240302` medium/scheduled) | 2 (identiques) |
| interventions | 2 | 2 |
| api_tokens | 1 | 1 |
| sites / customers | 1 / 1 | 1 / 1 |
| event_logs (documents dont `recorded_at` precede la sauvegarde) | 33 | 33 |

Les bases de test ont ensuite ete supprimees (`DROP DATABASE`, `dropDatabase` : `ok: 1`).

## 5. Diagnostic et correction du bug technique

Bug retenu : recherche de tickets combinee au filtre de priorite (indice 2 de la fiche). Les autres bugs corriges sont resumes en section 7.2.

### 5.1 Symptome observe

Sur la qualification, `GET /api/v1/tickets?search=Cooling&priority=critical` renvoyait le ticket `INC-240302`, dont la priorite est `medium`. Le filtre de priorite etait ignore des qu'une recherche etait saisie.

### 5.2 Demarche de diagnostic

1. Reproduction sur l'API avec le token du microservice, en variant les combinaisons :
   - `priority=critical` seul : correct ;
   - `search=Cooling` seul : correct ;
   - les deux ensemble : `INC-240302/medium` present.
2. Hypotheses : donnees incoherentes en base (ecartee, `priority=medium` confirme en SQL), cache (ecartee, l'endpoint API n'est pas cache), construction de la requete.
3. Lecture de `app/Http/Controllers/Api/TicketController.php`, methode `index` : `where('title', 'like', ...)->orWhereRaw("reference like '%{$search}%'")`, suivi de `where('priority', ...)`.
4. SQL produit : `where title like ? or reference like '%...%' and priority = ?`. Le `AND` est prioritaire sur le `OR`, donc le filtre ne s'applique qu'a la branche `reference`.

### 5.3 Cause racine identifiee

- Condition `OR` non groupee : il manque les parentheses autour de `title OR reference`.
- Le terme de recherche etait en plus concatene dans du SQL brut (`orWhereRaw`), ce qui constitue aussi la faille de la section 6.

### 5.4 Correctif applique

```diff
-            $query->where('title', 'like', "%{$search}%")
-                ->orWhereRaw("reference like '%{$search}%'");
+            $query->where(fn ($q) => $q->where('title', 'like', "%{$search}%")
+                ->orWhere('reference', 'like', "%{$search}%"));
```

Le `where` imbrique produit `(title like ? or reference like ?) and priority = ?`, avec des parametres lies. Commit « Fix ticket search grouping and SQL injection », deploye en qualification puis en production. Diff complet des correctifs : `annexes/04/correctifs.diff`.

### 5.5 Verification apres correction

Rejoue sur la production, sur la qualification et sur l'environnement Docker local :

```
T1 search=Cooling&priority=critical (attendu total 0)
"total":0
T2 search=INC&priority=critical (attendu INC-240301 seul)
"reference":"INC-240301" "total":1
T3 search=' (attendu 200)
200
```

## 6. Diagnostic et correction de la faille de securite

Faille retenue : injection SQL dans la recherche de tickets (indice 6, « entree mal formee »). Les autres failles sont listees en section 7.2 et dans `SECURITY.md` (livrable 05).

### 6.1 Faille identifiee

- Parametre `search` de `GET /api/v1/tickets`, concatene sans echappement dans `orWhereRaw("reference like '%{$search}%'")`.
- Toute apostrophe casse la requete, et une charge construite permet de modifier la clause SQL.

### 6.2 Demarche de diagnostic

1. Test d'entree mal formee : `GET /api/v1/tickets?search=%27` renvoie HTTP 500.
2. `laravel.log` (qualification), 07:28:07 UTC : `SQLSTATE[42000] ... 1064 You have an error in your SQL syntax ... near '%''`. L'apostrophe est transmise telle quelle a MySQL.
3. Lecture du code (section 5.2, etape 3) : interpolation PHP `{$search}` dans une chaine SQL brute, aucun parametre lie.
4. Recherche d'autres requetes brutes dans `app/` : aucune autre occurrence de `whereRaw`, `DB::raw` ou `DB::statement` avec entree utilisateur.

### 6.3 Evaluation du risque

| Critere | Evaluation |
| --- | --- |
| Vecteur | requete HTTP sur un point d'entree expose publiquement |
| Prerequis | un token API valide (le token du microservice est partage) |
| Impact | lecture de toute la base accessible au compte applicatif : utilisateurs et hachages de mots de passe, token API en clair (`api_tokens`), donnees clients (contacts, telephones) ; alteration possible des resultats ; divulgation d'informations via les erreurs quand `APP_DEBUG=true` (qualification) |
| Severite | Haute (Critique si le token fuite, ce qui est plausible : il est partage avec un second service) |

### 6.4 Mesure corrective appliquee

- Requete reecrite avec le Query Builder et des parametres lies (diff de la section 5.4). L'entree utilisateur n'est plus jamais concatenee au SQL.
- Mesures de defense en profondeur livrees en parallele :
  - controle des droits du token par route (`tickets:read`, `tickets:write`, `weather:read`), qui limite ce qu'un token compromis peut faire ;
  - `APP_DEBUG=false` en production, sans trace SQL dans les reponses ;
  - compte MySQL applicatif limite a sa base.

### 6.5 Verification apres correction

- `search=%27` renvoie 200 et une liste vide, en qualification, en production et en local Docker.
- `laravel.log` de production : aucune erreur SQL depuis le deploiement. La seule ligne `ERROR` est l'echec de migration de 07:54:34 UTC, anterieur au correctif de migration.
- Token temporaire limite a `tickets:read` : GET 200, PATCH 403, `external/weather` 403.

## 7. Autres observations

### 7.1 Identification de la source des appels suspects

Webhook `hooks.php` (indice 3 : « appele regulierement ») :
- Aucun cron ni timer ne l'appelle, sur aucun serveur : verifie dans `/etc/cron*`, les crontabs `root`, `ubuntu` et `www-data`, et `systemctl list-timers`.
- Dans les access logs Apache (y compris les archives), les seuls appelants sont `127.0.0.1` (tests locaux) et le poste du candidat, aux heures exactes des tests.
- Aucun emetteur externe n'a donc ete observe pendant l'epreuve.
- Le webhook exigeait seulement une authentification HTTP Basic avec des identifiants de demonstration : il est desormais protege par une signature HMAC (section 7.2).

SSH, commandes utilisees :

```bash
zcat -f /var/log/auth.log* | grep -E 'Invalid user|Failed password' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -rn
zcat -f /var/log/auth.log* | grep -oE 'Invalid user [^ ]+' | awk '{print $3}' | sort | uniq -c | sort -rn
zcat -f /var/log/auth.log* | grep 'Accepted publickey'
```

| Serveur | Source | Fenetre | Tentatives | Comptes vises | Succes | Requetes web |
| --- | --- | --- | --- | --- | --- | --- |
| Production | `37.140.242.106` | 10/09 07:16:25 – 07:18:28 | 266 | user, debian, admin, pi, ftp | 0 | 0 |
| Qualification | `89.238.165.139` | 09/09 22:57:05 – 22:57:42 | 266 | idem | 0 | 0 |
| Qualification | `193.95.2.23` | 10/09 00:27:49 – 00:28:51 | 266 | idem | 0 | 0 |

Analyse :
- Attaques par dictionnaire automatisees : rafales de 1 a 2 minutes, noms de comptes generiques.
- Elles ont echoue parce que l'authentification par mot de passe est desactivee.
- fail2ban (jail `sshd`) les bannit desormais apres 5 echecs.

Connexions acceptees : uniquement avec la cle remise par le centre (empreinte `SHA256:L2U0J1CI...`), depuis trois sources :
- l'IP de l'operateur lors de l'installation du 15/03 (`apt-get install`, `timedatectl` dans `auth.log`) ;
- le poste du candidat ;
- `89.238.174.15` le 09/09 a 19:04, pour une session de 3 secondes sur les deux serveurs, deux minutes apres leur demarrage (EC2 Instance Connect). C'est coherent avec un controle automatique du centre, pas avec une intrusion.

Web :
- Sondes de scanners : `GET /.git/config` en production (`64.62.156.122`), `GET /.git/index` en qualification (`80.13.153.140`). Toutes ont recu une 404 : pas de depot expose.
- Aucune requete d'injection observee en dehors des tests du candidat.

### 7.2 Autres bugs et failles corriges

| # | Type | Constat | Correction |
| --- | --- | --- | --- |
| 1 | Bug | Compteurs du tableau de bord obsoletes : cache `dashboard.kpis` de 30 minutes jamais invalide | `Cache::forget('dashboard.kpis')` sur `saved` et `deleted` du modele `Ticket`. Verifie : ligne de cache 1, puis 0 apres modification d'un ticket |
| 2 | Bug | `hooks.php` repondait 500 (`Class "config" does not exist`) : le noyau Laravel n'etait pas initialise | `$kernel->bootstrap()`, liaison de la requete, rendu des exceptions en JSON |
| 3 | Bug | Webhook : statut recu ignore (ticket force a `scheduled`), une intervention creee a chaque appel | statut valide et applique, deduplication sur `external_event_id`. Verifie : 422 sur statut invalide, rejeu `Webhook already processed.` |
| 4 | Bug | Microservice de supervision vide : lecture de `payload.items` au lieu de `payload.data` | `payload.data`. Verifie : `INC-240301 INC-240302` affiches |
| 5 | Bug d'exploitation | `migrate` en echec (`SQLSTATE 1824`) : migrations au meme horodatage, `interventions` avant `tickets` | migration renommee (`183115`) |
| 6 | Bug d'exploitation | Assets Next.js en 404 via Apache | vhost : `ProxyPass /_next/` vers `127.0.0.1:3000` |
| 7 | Faille | Droits du token API jamais verifies | parametre de middleware `api.token:<droit>` par route. Verifie : 200 / 403 / 403 |
| 8 | Faille | `hooks.php` protege par HTTP Basic seul, sans signature ni restriction d'origine | en-tete `X-OpsTrack-Signature` obligatoire (HMAC-SHA256 du corps, `hash_equals`), liste d'IP optionnelle, refus si la configuration est absente. Verifie : sans signature, mauvais secret ou corps altere = 401 ; signe = 200 ; IP hors liste = 403 |
| 9 | Faille | `.env.example` contenait les identifiants de demonstration, avec un repli `user` / `password` dans `config/services.php` | valeurs videes, repli retire |
| 10 | Faille d'exploitation | Production initiale : pas de HTTPS, pare-feu inactif, compte `root` MySQL par defaut | livrable 02 |
| 11 | Faille (dependance) | Microservice en `next` 15.3.1, expose via `/dispatch-dashboard`. Detecte dans le journal du pipeline (`This version has a security vulnerability`), confirme par la base GitHub Advisory : avis critiques d'execution de code a distance `GHSA-9qr9-h5gf-34mp` et `GHSA-2xp9-vwfh-vxw4`. `npm audit` : `3 vulnerabilities (2 high, 1 critical)` | montee en `next` 15.5.25 (commit `80410fb`), validee par un build local, deployee par le pipeline (run 3 : qualification puis production, smoke tests OK). Verifie : 15.5.25 en service sur les deux serveurs, plus aucun avis critique dans `npm audit` (residuel detaille en 7.5) |

### 7.3 Anomalie de supervision detectee et corrigee

Apres activation, fail2ban indiquait `Total failed: 0` malgre les attaques de la section 7.1.

Diagnostic :
- `journalctl _COMM=sshd -o verbose` : les lignes sont rattachees a `_SYSTEMD_UNIT=ssh.service` (nom de l'unite sur Ubuntu 24.04), alors que le filtre fourni cherche `sshd.service` ;
- `fail2ban-regex` sur `auth.log` reconnait bien 271 lignes, donc la regle est bonne mais la source ne l'etait pas.

Correction : `journalmatch = _SYSTEMD_UNIT=ssh.service + _COMM=sshd` dans `ops/fail2ban/opstrack.local`.

Verification apres correction (production, 12:11) :

```
$ sudo fail2ban-client get sshd journalmatch
_SYSTEMD_UNIT=ssh.service + _COMM=sshd
$ sudo fail2ban-regex -m '_SYSTEMD_UNIT=ssh.service + _COMM=sshd' systemd-journal sshd
Lines: 938 lines, 545 ignored, 272 matched, 121 missed
# une seule tentative de connexion volontairement invalide (compte inexistant), sous le seuil de bannissement :
$ sudo fail2ban-client status sshd
|  |- Currently failed: 1
|  |- Total failed:     1
/var/log/fail2ban.log : [sshd] Found <ip du poste> - 2026-09-10 12:11:40
```

Le pipeline de deploiement a lui aussi remonte une alerte, dans le cadre d'un echec reel (livrable 03) : `12:05:41 | OpsTrack deploiement | Echec du workflow Deploy #1`.

### 7.4 Simulation de panne (qualification)

Deroule :
1. le service `opstrack-dispatch-dashboard` est arrete sur la qualification, puis les sondes sont executees ;
2. le service est redemarre, puis les sondes sont executees de nouveau.

Resultat attendu et obtenu : alertes `services` et `dashboard`, puis messages `RETABLI` (sortie ci-dessous).

```
12:09:10 arret de opstrack-dispatch-dashboard, puis sondes :
opstrack-healthcheck: http_health=ok
opstrack-healthcheck: dashboard=ko aucun ticket affiche
opstrack-healthcheck: services=ko inactif(s) : opstrack-dispatch-dashboard
12:09:23 redemarrage du service, puis sondes :
opstrack-healthcheck: dashboard=ok
opstrack-healthcheck: services=ok

Notifications recues sur le topic ntfy :
12:09:10 | OpsTrack ip-172-31-42-35 | ALERTE dashboard : aucun ticket affiche
12:09:11 | OpsTrack ip-172-31-42-35 | ALERTE services : inactif(s) : opstrack-dispatch-dashboard
12:09:23 | OpsTrack ip-172-31-42-35 | RETABLI dashboard
12:09:24 | OpsTrack ip-172-31-42-35 | RETABLI services
```

Delai de detection : 5 minutes au plus en fonctionnement normal (periode du timer). Ici les sondes ont ete lancees a la main pour le test.

### 7.5 Anomalies identifiees non corrigees

- Modele `EventLog` : propriete `$collection` ignoree, documents dans `event_logs` au lieu de `app_events` (fonctionnel, a aligner).
- `ext-mongodb` 2.1.4 alors que le lockfile exige ^2.2 (installation avec `--ignore-platform-req`).
- Node.js 18 en production, hors support.
- Dependances du microservice apres montee en Next 15.5.25 : `npm audit --omit=dev` renvoie `3 vulnerabilities (1 moderate, 2 high)` en production, sans avis critique. Concernes : `postcss`, dont le correctif impose Next 16, et `sharp` / libvips (optimisation d'images, non utilisee par le microservice).
- Qualification volontairement laissee dans sa configuration d'origine (livrable 02, section 6).
- Pas de purge automatique des copies de sauvegarde cote qualification. La cle `rrsync` en ecriture seule ne permet pas de supprimer : prevoir un `find -mtime +30 -delete` local.
