#!/usr/bin/env bash
# Restaure une sauvegarde OpsTrack dans les bases indiquees (verification des empreintes d'abord).
# Usage : sudo bash ops/restore.sh <dossier_sauvegarde> <base_mysql_cible> <base_mongo_cible> [base_mongo_source]
# Acces MySQL : ~/.my.cnf ou MYSQL_PWD pour un compte autorise a creer la base cible.
set -euo pipefail
DIR=${1:?dossier de sauvegarde}
DB=${2:?base MySQL cible}
MONGO_DB=${3:?base MongoDB cible}
MONGO_SRC=${4:-opstrack_logs}

(cd "$DIR" && sha256sum -c SHA256SUMS)

mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
gunzip -c "$DIR/mysql.sql.gz" | mysql "$DB"

mongorestore --quiet --drop --gzip --archive="$DIR/mongodb.archive.gz" \
    --nsFrom="$MONGO_SRC.*" --nsTo="$MONGO_DB.*"

echo "Restauration terminee : MySQL $DB, MongoDB $MONGO_DB"
