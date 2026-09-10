#!/usr/bin/env bash
# Deploie un commit sur le serveur courant ; rollback du code si le smoke test local echoue.
# Usage : ssh ubuntu@<hote> "REMOTE=<remote git> REF=<sha> SMOKE_URL=<url locale> bash -s" < ops/deploy.sh
# Les migrations deja appliquees ne sont pas annulees par le rollback.
set -euo pipefail
APP=/var/www/opstrack
REMOTE=${REMOTE:-origin}
REF=${REF:?commit a deployer}
SMOKE_URL=${SMOKE_URL:-http://127.0.0.1}
cd "$APP"

apply() {
    local changed=$1 with_migrations=$2
    if grep -qx 'composer.lock' <<<"$changed"; then
        composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-req=ext-mongodb || return 1
    fi
    if [ "$with_migrations" = yes ] && grep -q '^database/migrations/' <<<"$changed"; then
        php artisan migrate --force || return 1
    fi
    if grep -q '^APP_ENV=production' .env; then
        php artisan config:cache && php artisan route:cache && php artisan view:cache || return 1
    fi
    if grep -q '^microservices/dispatch-dashboard/' <<<"$changed"; then
        (cd microservices/dispatch-dashboard && npm install --no-audit --no-fund --loglevel=error && npm run build) || return 1
        sudo systemctl restart opstrack-dispatch-dashboard || return 1
    fi
    sudo systemctl reload apache2
}

smoke() {
    local attempt
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        [ "$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$SMOKE_URL/api/health")" = 200 ] && return 0
        sleep 3
    done
    return 1
}

PREVIOUS=$(git rev-parse HEAD)
git fetch -q "$REMOTE"
git merge --ff-only -q "$REF"
CURRENT=$(git rev-parse HEAD)
CHANGED=$(git diff --name-only "$PREVIOUS" "$CURRENT")
echo "Deploiement ${PREVIOUS:0:7} -> ${CURRENT:0:7} ($(grep -c . <<<"$CHANGED" || true) fichier(s))"

if apply "$CHANGED" yes && smoke; then
    echo "Deploiement reussi : ${CURRENT:0:7}"
    exit 0
fi

echo "ECHEC du deploiement de ${CURRENT:0:7} : rollback vers ${PREVIOUS:0:7}" >&2
git reset -q --keep "$PREVIOUS"
apply "$CHANGED" no || true
if smoke; then
    echo "Rollback reussi : ${PREVIOUS:0:7} en service" >&2
else
    echo "Rollback effectue (${PREVIOUS:0:7}) mais le smoke test echoue toujours" >&2
fi
exit 1
