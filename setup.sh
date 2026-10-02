#!/bin/sh
# Installs Nextcloud (SQLite) if needed, enables mounted apps, then runs the command.
set -eu

cd /var/www/html

# Make sure we run as www-data (re-exec if started as root)
if [ "$(id -u)" = "0" ]; then
    chown -R www-data:www-data /var/www/html/config /var/www/html/data 2>/dev/null || true
    exec su -s /bin/sh www-data -c 'exec /usr/local/bin/setup.sh "$@"' -- sh "$@"
fi

mkdir -p /var/www/html/data /var/www/html/config 2>/dev/null || true

ADMIN_USER="${NEXTCLOUD_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${NEXTCLOUD_ADMIN_PASSWORD:-admin}"

if php occ status 2>/dev/null | grep -Eq 'installed: *true'; then
    echo "Nextcloud already installed"
else
    php occ maintenance:install \
        --database sqlite \
        --admin-user "$ADMIN_USER" \
        --admin-pass "$ADMIN_PASSWORD" \
        --no-interaction
fi

# Enable apps that are not part of the server (e.g. mounted volumes)
for dir in apps/*/; do
    app="$(basename "$dir")"
    [ -f "$dir/appinfo/info.xml" ] || continue
    if grep -qx "$app" /opt/bundled-apps.txt; then
        continue
    fi
    php occ app:enable "$app" || echo "Warning: could not enable app $app" >&2
done

exec "$@"
