#!/usr/bin/env bash
# Sondes OpsTrack, lancees par opstrack-healthcheck.timer.
# Chaque sonde est journalisee (syslog, tag opstrack-healthcheck) ; une alerte ntfy part a chaque changement d'etat.
# Variables (/etc/opstrack/healthcheck.env) : BASE_URL, NTFY_TOPIC, SERVICES, CHECK_CERT (0/1), CHECK_BACKUP (0/1).
set -uo pipefail
APP=/var/www/opstrack
STATE=/var/lib/opstrack-healthcheck
: "${BASE_URL:?}" "${NTFY_TOPIC:?}" "${SERVICES:?}"
mkdir -p "$STATE"

notify() {
    curl -s -m 10 -H "Title: OpsTrack $(hostname)" -H "Priority: $2" -H "Tags: $3" -d "$1" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null
}

probe() {
    local name=$1 detail status previous
    shift
    if detail=$("$@" 2>&1); then status=ok; else status=ko; fi
    previous=$(cat "$STATE/$name" 2>/dev/null || echo ok)
    logger -t opstrack-healthcheck "$name=$status $detail"
    if [ "$status" != "$previous" ]; then
        if [ "$status" = ko ]; then
            notify "ALERTE $name : $detail" high warning
        else
            notify "RETABLI $name" default white_check_mark
        fi
        echo "$status" > "$STATE/$name"
    fi
}

http_health() {
    local code
    code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$BASE_URL/api/health")
    [ "$code" = 200 ] || { echo "GET /api/health : HTTP $code"; return 1; }
}

dashboard() {
    curl -s -m 10 "$BASE_URL/dispatch-dashboard" | grep -q 'INC-' || { echo "aucun ticket affiche"; return 1; }
}

services() {
    local down=()
    for service in $SERVICES; do
        systemctl is-active -q "$service" || down+=("$service")
    done
    [ ${#down[@]} -eq 0 ] || { echo "inactif(s) : ${down[*]}"; return 1; }
}

disk() {
    local usage
    usage=$(df --output=pcent / | tail -1 | tr -dc '0-9')
    [ "$usage" -lt 85 ] || { echo "disque / a ${usage} %"; return 1; }
}

certificate() {
    local host end days
    host=${BASE_URL#https://}
    host=${host%%/*}
    end=$(echo | openssl s_client -connect "$host:443" -servername "$host" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
    days=$(( ($(date -d "$end" +%s) - $(date +%s)) / 86400 ))
    [ "$days" -ge 14 ] || { echo "certificat expire dans $days jours"; return 1; }
}

# Sondes evenementielles : alerte si le compteur augmente depuis le passage precedent.
counter_increase() {
    local name=$1 current=$2 label=$3 previous
    previous=$(cat "$STATE/$name.count" 2>/dev/null || echo "$current")
    echo "$current" > "$STATE/$name.count"
    [ "$current" -le "$previous" ] || { echo "$((current - previous)) $label"; return 1; }
}

laravel_errors() {
    counter_increase laravel_errors "$(grep -c '\.ERROR' "$APP/storage/logs/laravel.log" 2>/dev/null || echo 0)" "nouvelle(s) erreur(s) dans laravel.log"
}

ssh_bans() {
    counter_increase ssh_bans "$(fail2ban-client status sshd | awk -F: '/Total banned/ {gsub(/ /, "", $2); print $2}')" "nouvelle(s) IP bannie(s) par fail2ban (sshd)"
}

backup_age() {
    local latest age
    latest=$(find /var/backups/opstrack -mindepth 1 -maxdepth 1 -type d -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
    [ -n "$latest" ] || { echo "aucune sauvegarde"; return 1; }
    age=$(( ($(date +%s) - ${latest%.*}) / 3600 ))
    [ "$age" -lt 26 ] || { echo "derniere sauvegarde il y a $age h"; return 1; }
}

probe http_health http_health
probe dashboard dashboard
probe services services
probe disk disk
probe laravel_errors laravel_errors
probe ssh_bans ssh_bans
[ "${CHECK_CERT:-0}" = 1 ] && probe certificate certificate
[ "${CHECK_BACKUP:-0}" = 1 ] && probe backup_age backup_age
exit 0
