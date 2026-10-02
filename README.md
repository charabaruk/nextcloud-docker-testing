# nextcloud-docker-testing

Docker images for developing and testing Nextcloud apps with PHPUnit. Each image is based on the
official `nextcloud:N` image and contains the matching Nextcloud server source (branch `stableN` of
[nextcloud/server](https://github.com/nextcloud/server), with submodules) in `/var/www/html`,
including `tests/bootstrap.php` and the composer dev dependencies (PHPUnit etc.).

This is a from-scratch replacement for the unmaintained SteKoe/nextcloud-docker-testing.

## Tags

`ghcr.io/charabaruk/nextcloud-docker-testing:stable24` … `:stable31`. Every build is also pushed as
`stableN-<short-sha>`. Images are rebuilt weekly. No version is currently excluded.

## Usage

The entrypoint (`setup.sh`) installs Nextcloud with SQLite (admin/admin, override with
`NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD`), enables every app in `/var/www/html/apps`
that is not bundled with the server, and then executes the given command. It is idempotent. The
container runs as `www-data`; the default command starts Apache on port 8080.

```sh
docker run --rm ghcr.io/charabaruk/nextcloud-docker-testing:stable30 phpunit --version

docker run --rm -v "$PWD:/var/www/html/apps/myapp" \
  ghcr.io/charabaruk/nextcloud-docker-testing:stable30 \
  phpunit --bootstrap tests/bootstrap.php apps/myapp/tests/
```

docker-compose (working directory is `/var/www/html`):

```yaml
services:
  app:
    image: ghcr.io/charabaruk/nextcloud-docker-testing:stable30
    volumes:
      - .:/var/www/html/apps/customproperties
      - ~/.nextcloud:/.nextcloud
```

```sh
docker compose run app phpunit --bootstrap tests/bootstrap.php apps/customproperties/tests/.
```

## Adding a Nextcloud version

Check that `nextcloud:N` exists on Docker Hub and that branch `stableN` exists in nextcloud/server,
then add `N` to `matrix.version` in `.github/workflows/docker-publish.yml`. If a version cannot be
built, remove it from the matrix and document the reason here.

## Making the package public

On GitHub: your profile/org → Packages → `nextcloud-docker-testing` → Package settings → Danger
Zone → Change visibility → Public. Other repositories' CI can then pull without authentication.
