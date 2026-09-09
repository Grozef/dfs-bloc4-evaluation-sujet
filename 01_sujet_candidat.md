# Sujet candidat

## Certification Développeur Full Stack - RNCP38606

### Bloc RNCP38606BC04

`Déployer et assurer le maintien en production d'une application`

---

| Champ | Valeur |
| --- | --- |
| Session | `10 septembre 2026` |
| Modalité | Mise en situation professionnelle simulée individuelle de maintenance d'une application |
| Durée totale | `5 heures` |
| Organisation | Partie 1 : 9 h–12 h — Partie 2 : 13 h–15 h |
| Format de diffusion | Document candidat, sans données confidentielles |
| Données sensibles | Remises séparément dans la fiche confidentielle individuelle |

## 1. Objet de l'épreuve

Le candidat intervient sur une application existante présentant des bugs techniques, des failles de sécurité, des composants à fiabiliser et des besoins de mise en production.

L'épreuve est construite pour evaluer les compétences du bloc 4 dans une logique de maintenance et d'exploitation réelles, sur un environnement technique fourni par le centre.

## 2. Compétences évaluées

| Code | Compétence évaluée | Preuves principales attendues |
| --- | --- | --- |
| `C27` | Produire la documentation technique d'une application et alimenter une base de connaissances pour la maintenance | Documentation générée, changelog, journal de sécurité, base de connaissances |
| `C28` | Administrer l'enregistrement et la configuration de noms de domaines et de certificats de sécurité | DNS, domaine, HTTPS, certificat fonctionnel |
| `C29` | Sélectionner une plateforme d'hébergement adaptée aux exigences techniques, économiques, qualitatives et réglementaires | Architecture cible, coût, élasticité, contraintes de conformité |
| `C30` | Administrer des services d'hébergement en appliquant les bonnes pratiques de sécurité pour maintenir la continuité de service | Production fonctionnelle, sécurisation, configuration reproductible |
| `C31` | Mettre en œuvre un système de déploiement automatisé respectant les bonnes pratiques DevOps | Pipeline ou script de déploiement, contrôles, smoke test |
| `C32` | Mettre en œuvre un système de supervision pour détecter, diagnostiquer et corriger bugs, incidents et failles | Journalisation, alertes, sauvegarde, diagnostic, correction |

## 3. Consignes générales

- L'accès à Internet et l'usage d'outils d'assistance, y compris d'IA générative, sont autorisés sauf instruction contraire du centre.
- Les téléphones portables et terminaux personnels non autorisés par le centre sont interdits pendant l'épreuve.
- Les messageries instantanees et toute communication entre candidats sont interdites pendant l'épreuve.
- Les informations d'accès, de session et les secrets techniques figurent dans la fiche confidentielle remise individuellement.
- Le candidat peut proposer des solutions techniques equivalentes à celles citees en exemple, à condition qu'elles soient justifiées, fonctionnelles et documentées.
- **Le candidat doit forker le présent dépôt pour y rendre ses livrables. Chaque livrable doit faire l'objet d'une Pull Request distincte vers le dépôt d'origine** (cf. section 7).

## 4. Environnement fourni

| Ressource | Description minimale attendue |
| --- | --- |
| Code source | Dépôt contenant l'application support |
| Qualification / préproduction | Environnement de travail et de vérification |
| Production | Environnement cible à administrer et mettre en service |
| Domaine public | Nom de domaine affecté à la production |
| Accès techniques | Accès SSH et, si nécessaire, accès applicatifs utiles à l'épreuve |

L'application support comporte au minimum :

- un front-end ;
- un back-end d'API ;
- une base de données relationnelle ;
- une base NoSQL ;
- au moins un micro-service serverless ;
- des intégrations externes de type API et webhook.

## 4 bis. Vue d'architecture de l'application support

L'application support `OpsTrack Field Service` repose sur les composants suivants :

| Composant | Rôle principal | Point d'attention pour l'épreuve |
| --- | --- | --- |
| `Laravel 12` | Application cœur métier, interface web principale, API REST et traitement du webhook `hooks.php` | Porte la logique métier, les intégrations et une partie des anomalies à diagnostiquer |
| `MySQL` | Données transactionnelles de l'application | Contient les entités métier principales : utilisateurs, tickets, interventions, commentaires |
| `MongoDB` | Journaux techniques et événements applicatifs | Utile pour le diagnostic, la traçabilité et l'analyse d'incidents |
| `Redis` | Cache applicatif et mécanismes de performance | Peut influencer le comportement observé sur les indicateurs et la cohérence des données affichées |
| `Next.js` | Microservice `dispatch-dashboard` dédié à l'affichage d'un tableau de bord secondaire | Consomme l'API Laravel et peut constituer un point d'entrée de diagnostic inter-services |
| API publique tierce | Enrichissement externe de certaines données de l'application | Sa disponibilité ou son intégration peuvent influencer certains traitements |

### Flux applicatifs principaux

- le front principal et l'API métier sont servis par l'application Laravel ;
- Laravel lit et écrit les données métier dans `MySQL` ;
- Laravel journalise certains événements et traces dans `MongoDB` ;
- `Redis` est utilisé pour accélérer certains traitements et stockages temporaires ;
- le microservice `Next.js` consomme l'API Laravel pour afficher un tableau de bord dédié ;
- un webhook appelle `hooks.php` à la racine du domaine pour injecter des événements externes ;
- l'application peut consommer une API publique pour enrichir certains traitements.

### Périmètre d'analyse recommandé au candidat

- vérifier d'abord le cœur Laravel et les dépendances de données (`MySQL`, `MongoDB`, `Redis`) ;
- controler ensuite les intégrations entrantes et sortantes : API, webhook et API publique ;
- considerer le microservice `Next.js` comme un composant distinct, dependant de l'API Laravel ;
- distinguer ce qui releve d'un probleme de code, de configuration, de données ou d'intégration entre services.

## 5. Travail demande

Les activites sont organisees par preuves de compétence. Une meme action peut contribuer à plusieurs compétences si elle est correctement tracee.

### 5.1 Synthese des attendus par partie

| Partie | Activite | Compétences | Livrable principal |
| --- | --- | --- | --- |
| Partie 1 | Architecture cible et choix de l'hébergement | `C29` | `01_architecture_hebergement.md` |
| Partie 1 | Exploitation sécurisée de la production, domaine et TLS | `C28`, `C30` | `02_exploitation_securisee.md` |
| Partie 1 | Déploiement automatisé qualification -> production | `C31` | `03_deploiement_ci_cd.md` |
| Partie 2 | Supervision, journalisation, sauvegarde et maintenance corrective | `C32` | `04_supervision_maintien.md` |
| Partie 2 | Documentation technique et transfert de connaissances | `C27` | `05_documentation_maintenance/` |

### 5.2 Partie 1 - Preparation du déploiement et mise en service

#### A. Architecture cible et choix de l'hébergement - `C29`

Depuis l'environnement de qualification et à partir de l'application fournie, le candidat doit :

- analyser les besoins techniques de l'application ;
- proposer une architecture cible d'hébergement pour une application en croissance ;
- justifier le choix d'un fournisseur et des services retenus ;
- estimer un coût annuel coherent ;
- expliciter les exigences qualitatives et réglementaires prises en compte.

L'architecture cible doit traiter au minimum :

- l'exposition publique des services ;
- l'isolation entre composants ;
- l'élasticité ou, à défaut, la capacite d'evolution ;
- la gestion des données relationnelles et NoSQL ;
- la sécurité, la sauvegarde et la supervision ;
- les contraintes de conformité utiles au contexte, notamment protection des données et traçabilité.

Il n'est pas demande d'implementer integralement cette architecture cible pendant l'épreuve. Elle doit être formalisee et argumentee.

#### B. Exploitation sécurisée de l'environnement de production - `C28` et `C30`

En tenant compte de la contrainte economique suivante, `dans un premier temps, la production repose sur une seule machine`, le candidat doit :

- mettre en service l'application sur l'environnement de production ;
- administrer les services necessaires à son fonctionnement ;
- appliquer des mesures de sécurisation adaptees ;
- documenter une configuration reproductible ;
- administrer le domaine attribué et mettre en service le HTTPS.

Les attendus minimaux portent sur :

- le service web et l'execution de l'application ;
- les droits d'accès et l'isolation minimale des services ;
- la configuration reseau et système utile au fonctionnement ;
- la gestion des secrets et des paramètres sensibles ;
- l'exposition controlee des services ;
- la resolution DNS et la mise en service du certificat.

#### C. Déploiement automatisé entre qualification et production - `C31`

Le candidat doit mettre en œuvre un système de déploiement automatisé permettant de promouvoir l'application depuis l'environnement de qualification vers l'environnement de production.

Le dispositif retenu doit permettre :

- un déclenchement explicite et reproductible ;
- la vérification d'un niveau minimal de qualité avant déploiement ;
- une mise à jour effective de la production ;
- une vérification post-déploiement de type `smoke test`.

### 5.3 Partie 2 - Maintien en production, supervision et documentation

#### D. Supervision, journalisation, sauvegarde et maintenance corrective - `C32`

Le candidat doit mettre en place ou configurer les moyens permettant de détecter, diagnostiquer et traiter un incident applicatif ou de sécurité.

Les attendus minimaux sont les suivants :

- une journalisation exploitable des services utiles ;
- des outils ou configurations d'audit adaptes au contexte ;
- des sondes et alertes pertinentes pour l'état des services et la sécurité ;
- une stratégie de sauvegarde et de restauration, ou à défaut de tolerance de panne, adaptée au contexte ;
- l'identification d'au moins un bug technique et la mise en œuvre d'un correctif ;
- l'identification d'au moins une faille de sécurité et la mise en œuvre d'une mesure corrective ;
- si le scenario fourni l'exige, l'identification de la source des appels suspects ou vulnerables.

Si une restauration complete n'est pas raisonnablement realisable sur la production pendant l'épreuve, le candidat peut valider sa procédure sur l'environnement de qualification, à condition de l'indiquer explicitement.

#### E. Documentation technique et transfert de connaissances - `C27`

Le candidat doit produire un ensemble documentaire exploitable par un pair charge de reprendre la maintenance de l'application.

Cet ensemble doit comporter :

- une documentation technique générée à partir du code source, hors dépendances tierces ;
- une documentation d'API ou, si elle n'est pas pertinente, une note de justification ;
- un `CHANGELOG` à jour ;
- un document de sécurité ou journal des corrections de sécurité à jour ;
- une base de connaissances ou note de passation expliquant le fonctionnement, les points d'attention, les procedures de déploiement, de supervision et de reprise.

## 6. Livrables attendus

| Livrable | Contenu attendu |
| --- | --- |
| `01_architecture_hebergement.md` | Architecture cible, diagramme de déploiement, justification, chiffrage annuel, élasticité, disponibilité et contraintes réglementaires |
| `02_exploitation_securisee.md` | Configuration production, DNS utiles, HTTPS, hardening, configuration reproductible |
| `03_deploiement_ci_cd.md` | Chaine de déploiement, outillage retenu, contrôles préalables, déclenchement, vérification post-déploiement, conduite à tenir en cas d'échec |
| `04_supervision_maintien.md` | Journalisation, audit, supervision, alertes, sauvegarde, diagnostic du bug, diagnostic de la faille, mesures correctives |
| `05_documentation_maintenance/` | Documentation technique générée, documentation d'API ou note de non-applicabilité, `CHANGELOG.md`, `SECURITY.md` ou `journal_securite.md`, `base_connaissances.md` ou `note_passation.md` |

## 7. Modalité de rendu

Les livrables sont rendus via GitHub selon la procédure suivante :

1. **Forker** ce dépôt (`dfs-bloc4-evaluation-sujet`) sur votre compte GitHub personnel.
2. Compléter les templates de livrables dans le dossier `livrables/` de votre fork.
3. Pour chaque livrable, creer une **Pull Request** distincte depuis votre fork vers le dépôt d'origine.
4. Nommer chaque Pull Request de maniere explicite, par exemple : `[Candidat 04] Livrable 01 — Architecture et hebergement`.
5. Les Pull Requests doivent être ouvertes **avant la fin de l'épreuve**.

> Les Pull Requests constituent la trace formelle de rendu. Tout livrable non soumis par Pull Request avant la fin de l'épreuve sera considéré comme non rendu.
