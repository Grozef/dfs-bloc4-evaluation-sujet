#!/usr/bin/env bash
# Pare-feu de la production : refus par defaut en entree, SSH, HTTP et HTTPS uniquement.
set -euo pipefail
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ufw status verbose
