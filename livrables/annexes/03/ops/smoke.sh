#!/usr/bin/env bash
# Smoke tests externes apres deploiement. Usage : bash ops/smoke.sh <url de base>
set -uo pipefail
BASE=${1:?url de base}
failed=0

check() {
    if [ "$2" = "$3" ]; then
        echo "OK    $1 ($3)"
    else
        echo "ECHEC $1 : attendu $2, obtenu $3"
        failed=1
    fi
}

code() { curl -s -o /dev/null -m 15 -w '%{http_code}' "$@"; }

check "GET /api/health" 200 "$(code "$BASE/api/health")"
check "GET /" 200 "$(code "$BASE/")"
check "API sans token" 401 "$(code -H 'Accept: application/json' "$BASE/api/v1/tickets")"
check "hooks.php sans authentification" 401 "$(code -X POST "$BASE/hooks.php")"
check "supervision affiche des tickets" oui "$(curl -s -m 15 "$BASE/dispatch-dashboard" | grep -q 'INC-' && echo oui || echo non)"

case "$BASE" in
    https://*)
        host=${BASE#https://}
        host=${host%%/*}
        check "HTTP redirige vers HTTPS" 301 "$(code "http://$host/")"
        end=$(echo | openssl s_client -connect "$host:443" -servername "$host" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
        days=$(( ($(date -d "$end" +%s) - $(date +%s)) / 86400 ))
        check "certificat valide plus de 7 jours" oui "$([ "$days" -gt 7 ] && echo oui || echo "non ($days j)")"
        ;;
esac

exit $failed
