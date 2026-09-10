Candidat 06 - LISOWSKI François

# Documentation d'API

Documentation redigee a partir du code source (`routes/api.php`, `app/Http/Controllers/Api/*`, `app/Http/Requests/*`, `app/Http/Resources/TicketResource.php`, `app/Http/Middleware/EnsureApiTokenIsValid.php`, `app/Http/Controllers/WebhookController.php`). Les exemples sont des reponses reelles, relevees le 10/09/2026 sur l'environnement Docker local et sur la production.

## 1. Vue d'ensemble de l'API

L'API REST d'OpsTrack expose les tickets d'intervention, les techniciens et un enrichissement meteo. Elle est consommee par le microservice `dispatch-dashboard` (Next.js) et par des clients tiers. Un webhook entrant (`hooks.php`) permet a un systeme externe de pousser l'avancement d'une intervention.

| Champ | Valeur |
| --- | --- |
| URL de base | `https://eval-dfs-p-tpl-20265-06.it-students.fr/api` (production), `http://localhost:8000/api` (Docker local) |
| Format | `JSON` (envoyer `Accept: application/json` ; `Content-Type: application/json` pour les corps) |
| Authentification | Token applicatif : `Authorization: Bearer <token>` ou en-tete `X-Api-Token: <token>`. Le token doit etre actif (`api_tokens.is_active`) et posseder le droit requis par la route (`abilities`) |
| Droits | `tickets:read`, `tickets:write`, `weather:read` |
| Pagination | liste des tickets paginee (15 par defaut, parametre `per_page`), cles `data`, `links`, `meta` |
| Versionnement | prefixe `/v1` |

Les tokens sont stockes dans la table `api_tokens` (`name`, `token`, `abilities` JSON, `is_active`, `last_used_at`). Le token du microservice est cree par le seeder a partir de `OPSTRACK_API_TOKEN`.

## 2. Endpoints disponibles

| Methode | Endpoint | Description | Authentification requise |
| --- | --- | --- | --- |
| GET | `/api/health` | Etat de l'application (`status`, `service`, `timestamp`) | Non |
| GET | `/up` | Sonde de sante native Laravel (HTML, 200) | Non |
| GET | `/api/v1/tickets` | Liste paginee des tickets. Parametres : `search` (titre ou reference, `LIKE`), `priority` (`low`, `medium`, `high`, `critical`), `per_page`, `page`. Tri : plus recents d'abord | Token `tickets:read` |
| GET | `/api/v1/tickets/{id}` | Detail d'un ticket (site, ouvreur, assigne, interventions) | Token `tickets:read` |
| POST | `/api/v1/tickets` | Creation d'un ticket. Reference `INC-XXXXXX` generee, statut `new` par defaut | Token `tickets:write` |
| PUT / PATCH | `/api/v1/tickets/{id}` | Mise a jour partielle. Passage a `resolved` ou `closed` : `closed_at` renseigne automatiquement | Token `tickets:write` |
| GET | `/api/v1/technicians` | Liste des utilisateurs de role `technician` (`id`, `name`, `email`, `phone`) | Token `tickets:read` |
| GET | `/api/v1/external/weather?site_id={id}` | Meteo courante du site via l'API publique Open-Meteo | Token `weather:read` |
| POST | `/hooks.php` | Webhook entrant de mise a jour d'intervention (section 3.6) | HTTP Basic + signature HMAC |

Regles de validation :

| Champ | Creation (`StoreTicketRequest`) | Mise a jour (`UpdateTicketRequest`) |
| --- | --- | --- |
| `site_id` | requis, entier, doit exister | — |
| `opened_by_user_id` | requis, entier, utilisateur existant | — |
| `assigned_to_user_id` | optionnel, utilisateur existant | optionnel, utilisateur existant |
| `title` | requis, 120 caracteres max | optionnel, 120 max |
| `description` | requis | optionnel |
| `priority` | requis : `low`, `medium`, `high`, `critical` | optionnel, memes valeurs |
| `status` | optionnel : `new`, `scheduled`, `in_progress`, `resolved`, `closed` | optionnel, memes valeurs |
| `sla_due_at` | optionnel, date | optionnel, date |
| `closed_at` | — | optionnel, date |

Effets de bord :
- Chaque liste, creation ou mise a jour de ticket ecrit un evenement dans MongoDB (`opstrack_logs.event_logs`).
- Toute modification de ticket invalide le cache des indicateurs du tableau de bord.

## 3. Exemples de requetes et reponses

### 3.1 Sante

```
GET /api/health
```
```json
{"status":"ok","service":"OpsTrack","timestamp":"2026-09-10T10:14:24+00:00"}
```

### 3.2 Liste filtree des tickets

```
GET /api/v1/tickets?priority=critical&per_page=1
Authorization: Bearer <token>
Accept: application/json
```
```json
{
  "data": [{
    "id": 1, "reference": "INC-240301", "title": "Intermittent payment terminal outage",
    "description": "Three terminals restart during peak hours and the store asks for a fast onsite intervention.",
    "priority": "critical", "status": "in_progress",
    "sla_due_at": "2026-09-10T12:48:11+00:00", "closed_at": null,
    "site": {"id": 1, "name": "Lyon Confluence", "city": "Lyon"},
    "opened_by": {"id": 1, "name": "Nora Besson"},
    "assigned_to": {"id": 2, "name": "Lina Perez"},
    "interventions": [{"id": 1, "status": "in_progress", "scheduled_for": "2026-09-10T07:48:11+00:00", "started_at": "2026-09-10T08:08:11+00:00", "ended_at": null}],
    "updated_at": "2026-09-10T08:48:11+00:00"
  }],
  "links": {"first": "http://localhost:8000/api/v1/tickets?page=1", "last": "http://localhost:8000/api/v1/tickets?page=1", "prev": null, "next": null},
  "meta": {"current_page": 1, "from": 1, "last_page": 1, "path": "http://localhost:8000/api/v1/tickets", "per_page": 1, "to": 1, "total": 1, "links": ["..."]}
}
```

Recherche combinee : `GET /api/v1/tickets?search=Cooling&priority=critical` renvoie `"total":0`. Le filtre de priorite s'applique bien au resultat de la recherche.

### 3.3 Creation d'un ticket

```
POST /api/v1/tickets
Authorization: Bearer <token>
Content-Type: application/json

{"site_id":1,"opened_by_user_id":1,"assigned_to_user_id":2,"title":"Exemple documentation","description":"Ticket cree pour la documentation API","priority":"high"}
```
```json
{"data":{"id":3,"reference":"INC-003743","title":"Exemple documentation","description":"Ticket cree pour la documentation API","priority":"high","status":"new","sla_due_at":null,"closed_at":null,"site":{"id":1,"name":"Lyon Confluence","city":"Lyon"},"opened_by":{"id":1,"name":"Nora Besson"},"assigned_to":{"id":2,"name":"Lina Perez"},"interventions":[],"updated_at":"2026-09-10T10:14:25+00:00"}}
```

Corps invalide (`{"title":"","priority":"urgent"}`), HTTP 422 :

```json
{"message":"The site id field is required. (and 4 more errors)","errors":{"site_id":["The site id field is required."],"opened_by_user_id":["The opened by user id field is required."],"title":["The title field is required."],"description":["The description field is required."],"priority":["The selected priority is invalid."]}}
```

### 3.4 Mise a jour

```
PATCH /api/v1/tickets/2
Authorization: Bearer <token>
Content-Type: application/json

{"status":"in_progress"}
```
Reponse 200 : le ticket complet, au meme format que 3.2, avec `"status":"in_progress"`.

### 3.5 Techniciens et meteo

```
GET /api/v1/technicians
```
```json
{"data":[{"id":2,"name":"Lina Perez","email":"lina.perez@opstrack.test","phone":"06 22 33 44 55"},{"id":3,"name":"Mathis Leroy","email":"mathis.leroy@opstrack.test","phone":"06 99 88 77 66"}]}
```

```
GET /api/v1/external/weather?site_id=1
```
```json
{"data":{"provider":"open-meteo","site":"Lyon Confluence","city":"Lyon","current":{"time":"2026-09-10T10:00","interval":900,"temperature_2m":19.5,"weather_code":0,"wind_speed_10m":18.4},"fetched_at":"2026-09-10T10:14:25+00:00"}}
```

Appel sortant : `GET https://api.open-meteo.com/v1/forecast?latitude=..&longitude=..&current=temperature_2m,weather_code,wind_speed_10m`, avec un delai maximal de 8 s. Si Open-Meteo est indisponible, l'exception HTTP est rendue en 500.

### 3.6 Webhook `hooks.php`

Point d'entree a la racine du domaine, hors routeur Laravel. Controles, dans l'ordre :

1. Si `WEBHOOK_ALLOWED_IPS` est renseigne (IP ou CIDR separes par des virgules), une IP source hors liste recoit 403 `Forbidden`.
2. Authentification HTTP Basic (`WEBHOOK_BASIC_USER` / `WEBHOOK_BASIC_PASSWORD`). Si elle est absente ou fausse, ou si la configuration est vide, la reponse est 401 `Unauthorized`.
3. En-tete `X-OpsTrack-Signature` : HMAC-SHA256 hexadecimal du corps brut, calcule avec `WEBHOOK_SIGNING_SECRET`. S'il est absent ou different, la reponse est 401 `Invalid signature.`
4. Validation du corps (voir le tableau), puis 422 si invalide.
5. Deduplication : si `external_event_id` a deja ete traite, la reponse est 200 `Webhook already processed.`, sans aucune ecriture.
6. Creation d'une intervention, application du statut au ticket (`closed_at` renseigne pour `resolved` et `closed`), evenement MongoDB `intervention.synced`.

| Champ | Regle |
| --- | --- |
| `ticket_reference` | requis, reference existante (sinon 404) |
| `status` | requis : `new`, `scheduled`, `in_progress`, `resolved`, `closed` |
| `summary` | optionnel |
| `external_event_id` | optionnel, 255 caracteres max, cle de deduplication |

Exemple emetteur (bash) :

```bash
BODY='{"ticket_reference":"INC-240302","status":"scheduled","summary":"Exemple","external_event_id":"evt-doc-1"}'
SIG=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac "$WEBHOOK_SIGNING_SECRET" | awk '{print $NF}')
curl -u "$WEBHOOK_USER:$WEBHOOK_PASSWORD" -H 'Content-Type: application/json' -H 'Accept: application/json' \
     -H "X-OpsTrack-Signature: $SIG" -d "$BODY" https://<domaine>/hooks.php
```
```json
{"message":"Webhook processed.","intervention_id":6}
```

La signature doit etre calculee sur les octets EXACTS envoyes : un corps reformate ou modifie apres signature est refuse.

## 4. Codes d'erreur

Toutes les erreurs sont renvoyees en JSON avec une cle `message`. En production (`APP_DEBUG=false`), aucune trace ni aucun chemin de fichier n'est inclus.

| Code | Signification |
| --- | --- |
| 200 | Succes (lecture, mise a jour, webhook traite ou deja traite) |
| 201 | Non utilise : la creation renvoie 200 avec la ressource (`TicketResource`) |
| 401 | `{"message":"Missing API token."}` (pas de token), `{"message":"Invalid API token."}` (token inconnu ou inactif). Webhook : `Unauthorized` (Basic) ou `Invalid signature.` |
| 403 | `{"message":"Insufficient token ability."}` : le token n'a pas le droit exige par la route. Webhook : `Forbidden` (IP hors liste) |
| 404 | Ressource inexistante, par exemple `{"message":"No query results for model [App\\Models\\Ticket] 999"}` (ticket, site meteo, reference de webhook) |
| 405 | Methode non supportee, par exemple `{"message":"The DELETE method is not supported for route api/v1/tickets/1. Supported methods: GET, HEAD, PUT, PATCH."}` |
| 422 | Validation echouee : `message` et detail par champ dans `errors` |
| 500 | Erreur serveur (base indisponible, API Open-Meteo en echec). Message generique en production, detail dans `storage/logs/laravel.log` |
