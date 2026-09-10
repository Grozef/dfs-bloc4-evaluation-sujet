#!/usr/bin/env bash
# Durcissement et supervision d'un serveur OpsTrack (idempotent).
# Usage : sudo bash ops/provision.sh [--with-backup]
# Prerequis : /etc/opstrack/healthcheck.env (et /etc/opstrack/backup.env avec --with-backup).
set -euo pipefail
OPS=$(cd "$(dirname "$0")" && pwd)

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq fail2ban auditd >/dev/null

# fail2ban : bannissement des tentatives SSH
install -m 644 "$OPS/fail2ban/opstrack.local" /etc/fail2ban/jail.d/opstrack.local
systemctl enable -q fail2ban
systemctl restart fail2ban

# sshd : pas de X11, pas de connexion root
install -m 644 "$OPS/ssh/99-opstrack.conf" /etc/ssh/sshd_config.d/99-opstrack.conf
sshd -t
systemctl reload-or-restart ssh

# auditd : surveillance des secrets et des fichiers de configuration sensibles
install -m 640 "$OPS/audit/opstrack.rules" /etc/audit/rules.d/opstrack.rules
systemctl enable -q --now auditd
augenrules --load

# Apache : signature masquee, en-tetes de securite
install -m 644 "$OPS/apache/zz-opstrack-security.conf" /etc/apache2/conf-available/zz-opstrack-security.conf
a2enconf -q zz-opstrack-security
apache2ctl configtest
systemctl reload apache2

# Rotation des journaux Laravel
install -m 644 "$OPS/logrotate/opstrack" /etc/logrotate.d/opstrack

# Sondes et sauvegardes (timers systemd)
install -m 644 "$OPS"/systemd/opstrack-healthcheck.{service,timer} /etc/systemd/system/
if [ "${1:-}" = "--with-backup" ]; then
    install -m 644 "$OPS"/systemd/opstrack-backup.{service,timer} /etc/systemd/system/
fi
systemctl daemon-reload
systemctl enable -q --now opstrack-healthcheck.timer
if [ "${1:-}" = "--with-backup" ]; then
    systemctl enable -q --now opstrack-backup.timer
fi

echo "Provisionnement termine."
