ARG NEXTCLOUD_VERSION=30
FROM nextcloud:${NEXTCLOUD_VERSION}

# Re-declare after FROM so it is available in this build stage
ARG NEXTCLOUD_VERSION

# Debian bullseye (nextcloud:24/25 bases) is EOL: its security repository is gone from
# deb.debian.org and archive.debian.org has no bullseye-security suite, so fall back to the
# archived main suite only (allowing downgrades of packages the base image took from security).
RUN PKGS="git unzip"; \
    (apt-get update && apt-get install -y --no-install-recommends $PKGS) \
    || ( . /etc/os-release \
         && printf '%s\n' "deb http://archive.debian.org/debian ${VERSION_CODENAME} main" \
              > /etc/apt/sources.list \
         && rm -f /etc/apt/sources.list.d/debian.sources \
         && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive \
         && apt-get update \
         && apt-get install -y --no-install-recommends --allow-downgrades $PKGS ); \
    rc=$?; rm -rf /var/lib/apt/lists/*; exit $rc

# The official image already ships the PHP extensions Nextcloud needs
# (gd, zip, pdo_sqlite, intl, apcu, ...) for the matching PHP version.
# Only add zip if a base image happens to lack it.
RUN php -m | grep -qi '^zip$' || docker-php-ext-install zip

# Composer (only if the base image does not already provide it)
COPY --from=composer:2 /usr/bin/composer /tmp/composer
RUN command -v composer >/dev/null 2>&1 || install -m 0755 /tmp/composer /usr/local/bin/composer; \
    rm -f /tmp/composer

# PHP memory limit (zz- prefix so it is loaded after the base image's own setting)
ENV PHP_MEMORY_LIMIT=2048M
RUN echo 'memory_limit=2048M' > /usr/local/etc/php/conf.d/zz-memory-limit.ini

# Replace the packaged Nextcloud with the matching server source tree
RUN find /var/www/html -mindepth 1 -delete \
    && git clone --depth=1 --branch "stable${NEXTCLOUD_VERSION}" \
        --recurse-submodules --shallow-submodules \
        https://github.com/nextcloud/server.git /var/www/html \
    && git config --system --add safe.directory /var/www/html

WORKDIR /var/www/html

# Server dependencies including dev dependencies. Branches 28+ keep PHPUnit in
# vendor-bin/phpunit; 24-27 do not depend on PHPUnit at all, so it is installed
# separately in /opt/phpunit.
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install --no-interaction --no-progress \
    && if [ -f vendor-bin/phpunit/composer.json ]; then \
         composer install --no-interaction --no-progress --working-dir=vendor-bin/phpunit; \
       fi \
    && if [ -e vendor-bin/phpunit/vendor/bin/phpunit ]; then \
         ln -sf /var/www/html/vendor-bin/phpunit/vendor/bin/phpunit /usr/local/bin/phpunit; \
       elif [ -e vendor/bin/phpunit ]; then \
         ln -sf /var/www/html/vendor/bin/phpunit /usr/local/bin/phpunit; \
       else \
         mkdir /opt/phpunit \
         && composer require --working-dir=/opt/phpunit --no-interaction --no-progress "phpunit/phpunit:^9.6" \
         && ln -sf /opt/phpunit/vendor/bin/phpunit /usr/local/bin/phpunit; \
       fi \
    && phpunit --version \
    && test -f tests/bootstrap.php

# Record the apps that ship with the server so setup.sh only enables mounted ones
RUN ls -1 apps > /opt/bundled-apps.txt

# Run Apache as www-data on an unprivileged port
RUN sed -i 's/Listen 80$/Listen 8080/; s/Listen 443$/Listen 8443/' /etc/apache2/ports.conf \
    && sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/*.conf \
    && mkdir -p /var/run/apache2 /var/lock/apache2 /var/log/apache2 \
    && chown -R www-data:www-data /var/www/html /var/run/apache2 /var/lock/apache2 /var/log/apache2

COPY setup.sh cmd.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/setup.sh /usr/local/bin/cmd.sh

USER www-data
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/setup.sh"]
CMD ["/usr/local/bin/cmd.sh"]
