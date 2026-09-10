#!/usr/bin/env bash
# Sauvegarde OpsTrack : MySQL, MongoDB et configuration, retention locale et copie hors machine.
# Lance par opstrack-backup.timer. Variable optionnelle : BACKUP_REMOTE (destination rsync).
set -euo pipefail
APP=/var/www/opstrack
DEST=/var/backups/opstrack
KEEP_DAYS=7
DIR="$DEST/$(date +%Y%m%d-%H%M%S)"

env_value() { grep -E "^$1=" "$APP/.env" | head -1 | cut -d= -f2- | sed 's/^"//;s/"$//'; }

install -d -m 700 "$DEST" "$DIR"

MYSQL_PWD="$(env_value DB_PASSWORD)" mysqldump --single-transaction --no-tablespaces \
    -h "$(env_value DB_HOST)" -u "$(env_value DB_USERNAME)" "$(env_value DB_DATABASE)" | gzip > "$DIR/mysql.sql.gz"

mongodump --quiet --host "$(env_value MONGODB_HOST)" --port "$(env_value MONGODB_PORT)" \
    --db "$(env_value MONGODB_DATABASE)" --archive="$DIR/mongodb.archive.gz" --gzip

config=()
for path in var/www/opstrack/.env var/www/opstrack/microservices/dispatch-dashboard/.env.local \
    etc/apache2/sites-available etc/systemd/system/opstrack-dispatch-dashboard.service etc/letsencrypt etc/opstrack; do
    [ -e "/$path" ] && config+=("$path")
done
tar -czf "$DIR/config.tar.gz" -C / "${config[@]}"

(cd "$DIR" && sha256sum -- *.gz > SHA256SUMS)

find "$DEST" -mindepth 1 -maxdepth 1 -type d -mtime +"$KEEP_DAYS" -exec rm -rf {} +

if [ -n "${BACKUP_REMOTE:-}" ]; then
    rsync -a -e "ssh -i /root/.ssh/opstrack_backup -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes" "$DIR" "$BACKUP_REMOTE"
fi

echo "Sauvegarde terminee : $DIR"
