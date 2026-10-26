# Upgrading major versions

How to take a stack to the next major (e.g. PostgreSQL 17 to 18, MariaDB 11 to 12,
Nextcloud 34 to 35). The rule that makes this safe: never point a newer major
database image at an existing data volume. Dump, swap the volume contents, restore.
Traefik, nginx and Redis have no on-disk state that survives majors in a
meaningful way, so those are simple tag bumps.

All commands run on the deploy server as the deploy user (the same one
`terraform.tfvars` uses). Replace `<name>` with the app name (`cyberbits`, `images`, ...).

## 1. Before anything: versions and backups

Image versions live in three places, keep them in sync:
`variables.tf` (defaults), `terraform.tfvars` (`traefik_version`,
`nextcloud_images`), `terraform.tfvars.example`.

Back up every database, and snapshot every volume you are about to wipe:

```sh
# WordPress DB dump
docker exec wp-<name>-db sh -c 'mariadb-dump -u root -p"$MYSQL_ROOT_PASSWORD" \
  --single-transaction --routines --triggers --databases <name>_wp' \
  | gzip > /opt/wordpress-apps/<name>/pre-$(date +%F).sql.gz
gzip -t /opt/wordpress-apps/<name>/pre-*.sql.gz   # verify

# Nextcloud DB dump
docker exec nc-<name>-db pg_dumpall -U nextcloud | gzip > /opt/nextcloud-apps/<name>/pre-$(date +%F).sql.gz
gzip -t /opt/nextcloud-apps/<name>/pre-*.sql.gz

# Volume snapshot (pattern)
docker volume create <volume>-backup
docker run --rm -v <volume>:/from -v <volume>-backup:/to alpine sh -c 'cp -a /from/. /to/'

# Empty the original volume (pattern), only AFTER dump + snapshot
docker run --rm -v <volume>:/data alpine sh -c 'find /data -mindepth 1 -delete'
```

Rollback: run `tofu apply` with the old tag and copy the backup volume's contents
back (`cp -a /to/. /from/` with the mounts reversed).

## 2. WordPress: MariaDB major

```sh
docker stop wp-<name>-wpcli wp-<name>-app
# dump + snapshot + empty (see above), then bump wordpress_images.db in variables.tf
tofu apply        # replaces db (and redis, if bumped); the env credentials are unchanged
gunzip -c /opt/wordpress-apps/<name>/pre-*.sql.gz \
  | docker exec -i wp-<name>-db sh -c 'mariadb -u root -p"$MYSQL_ROOT_PASSWORD"'
docker start wp-<name>-wpcli wp-<name>-app
docker restart wp-<name>-nginx   # see gotcha below
```

Gotcha: the nginx sidecar resolves the PHP-FPM container's IP once at startup.
If the apply did not recreate it, it keeps talking to a dead IP and the site
returns 502. Restart it. Verify with `wp core version`, `wp db check`, and a
200 from the site.

## 3. Nextcloud: PostgreSQL major

```sh
docker stop nc-<name>-cron nc-<name>-app
# dump + snapshot + empty (see above), then bump nextcloud_images.db
tofu apply        # replaces the db container; app/cron stay stopped
```

PostgreSQL 18+ images change the layout: the volume must be mounted at
`/var/lib/postgresql` (the module's `db_data_path` default already is) and the
image refuses the legacy `/var/lib/postgresql/data` mount. The volume must be
completely empty on first start. Leftovers from failed starts make the entrypoint
exit-loop forever; if that happens: `docker stop`, empty the volume again, `docker start`.

```sh
# credentials come from the container env; user/db exist after init
docker exec nc-<name>-db psql -U nextcloud -d postgres -c 'DROP DATABASE IF EXISTS "nextcloud";'
gunzip -c /opt/nextcloud-apps/<name>/pre-*.sql.gz \
  | docker exec -i nc-<name>-db psql -U nextcloud -d postgres > /tmp/restore.log 2>&1
grep ERROR /tmp/restore.log   # expect exactly one: role "nextcloud" already exists (harmless)
```

## 4. Nextcloud major (do this after the PostgreSQL major)

```sh
docker exec nc-<name>-db pg_dumpall -U nextcloud | gzip > /opt/nextcloud-apps/<name>/pre-upgrade-$(date +%F).sql.gz
# bump nextcloud_images.nextcloud
tofu apply        # app + cron recreated; entrypoint runs `occ upgrade` automatically
# poll until healthy, then:
docker exec -u www-data nc-<name>-app php /var/www/html/occ status     # new version, maintenance: false
docker exec -u www-data nc-<name>-app php /var/www/html/occ app:list   # re-enable apps it disabled, if wanted
docker exec -u www-data nc-<name>-app php /var/www/html/occ db:add-missing-indices
```

The last command adds optional indices introduced by the new version. Nextcloud
deliberately does not do this during the upgrade; run it once afterwards, then
check that the "missing indices" warning in the admin overview is gone.

## 5. Redis majors (WordPress + Nextcloud)

Cache only: bump the tag, `tofu apply`. Cached keys are lost and rebuild automatically.

## 6. Verify everything

```sh
docker ps                       # every container healthy, on the expected tags
tofu plan                       # clean, no changes
curl -sI https://<every-site>   # 200
curl -s https://<nc-domain>/status.php   # new version, "needsDbUpgrade":false
docker exec wp-<name>-wpcli wp db check --path=/var/www/html --allow-root
docker exec -u www-data nc-<name>-app php /var/www/html/occ db:add-missing-indices   # reports nothing new
```

Keep the dump files and `-backup` volumes until the next successful backup cycle,
then delete them.
