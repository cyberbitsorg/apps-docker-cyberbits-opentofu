# Nextcloud Migration Design: old-images → images.cloudpro.io

**Date:** 2026-04-13

## Goal

Migrate all data from the old Nextcloud instance to the new one so that existing shared links (e.g. `https://old-images.cloudpro.io/s/kdm2K6odmocoe8r`) continue to work on the new domain (`https://images.cloudpro.io/s/kdm2K6odmocoe8r`).

## Instances

| | Old | New |
|---|---|---|
| Domain | old-images.cloudpro.io | images.cloudpro.io |
| IP | 162.55.217.28 | 46.224.167.12 |
| SSH | `ssh -i ~/.ssh/id_iohenkies iohenkies@162.55.217.28` | `ssh deployacc@46.224.167.12` |
| Admin user | iohenkies | henkbatelaan (overwritten) |

## Approach

Full one-way migration using PostgreSQL dump + Nextcloud data volume rsync. The new instance is completely overwritten.

## Steps

1. Enable maintenance mode on old instance
2. Export PostgreSQL dump from old DB container
3. SCP dump to new server
4. Rsync Nextcloud data volume (server-to-server via SSH)
5. Stop Nextcloud containers on new server
6. Drop and recreate database, import dump into new DB container
7. Update `trusted_domains` in `config.php` to `images.cloudpro.io`
8. Start containers on new server
9. Run `occ maintenance:data-fingerprint` and `occ files:scan --all`
10. Disable maintenance mode and test shared links

## Post-migration user note

After migration the admin user on the new server will be `iohenkies` (from the old database). The `henkbatelaan` account is lost (acceptable, new instance was overwritten). No user rename needed since shared links are user-agnostic tokens stored in `oc_share`.

## Success criteria

- `https://images.cloudpro.io/s/kdm2K6odmocoe8r` returns the shared image
- Admin login works on new server with `iohenkies` credentials
