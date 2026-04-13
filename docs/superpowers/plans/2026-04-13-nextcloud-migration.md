# Nextcloud Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate all data from old Nextcloud (old-images.cloudpro.io / 162.55.217.28) to new Nextcloud (images.cloudpro.io / 46.224.167.12) so existing shared links keep working.

**Architecture:** PostgreSQL dump piped directly old→new over SSH; Nextcloud data volume transferred via tar-over-SSH pipe (no local disk required). After import, config.php is updated with new server's DB credentials and trusted domain.

**Tech Stack:** Docker, PostgreSQL, Nextcloud occ CLI, SSH, tar, rsync

---

### Task 1: Discover old server container and volume names

**Files:** none

- [ ] **Step 1: SSH to old server and list running containers**

```bash
ssh -i ~/.ssh/id_iohenkies iohenkies@162.55.217.28 "docker ps --format 'table {{.Names}}\t{{.Image}}'"
```

Expected: table showing Nextcloud app, db, cron, redis containers.

- [ ] **Step 2: List Docker volumes on old server**

```bash
ssh -i ~/.ssh/id_iohenkies iohenkies@162.55.217.28 "docker volume ls"
```

Note down the nextcloud data volume name and DB volume name.

- [ ] **Step 3: Get old volume mount paths**

```bash
ssh -i ~/.ssh/id_iohenkies iohenkies@162.55.217.28 \
  "docker volume inspect <OLD_NEXTCLOUD_VOLUME> | jq -r '.[].Mountpoint'"
```

---

### Task 2: Capture new server DB credentials (before touching anything)

**Files:** none

- [ ] **Step 1: Get the new server's PostgreSQL password from running container**

```bash
ssh deployacc@46.224.167.12 \
  "docker exec nc-images-db env | grep POSTGRES_PASSWORD"
```

Save the value as `NEW_DB_PASS` — you'll need it in Task 6.

- [ ] **Step 2: Confirm new server container names**

```bash
ssh deployacc@46.224.167.12 "docker ps --format 'table {{.Names}}\t{{.Status}}'"
```

Expected: `nc-images-app`, `nc-images-db`, `nc-images-cron`, `nc-images-redis` all running.

---

### Task 3: Enable maintenance mode on old server

**Files:** none

- [ ] **Step 1: Put old Nextcloud in maintenance mode**

```bash
ssh -i ~/.ssh/id_iohenkies iohenkies@162.55.217.28 \
  "docker exec <OLD_APP_CONTAINER> php occ maintenance:mode --on"
```

Expected output: `Maintenance mode enabled`

---

### Task 4: Transfer Nextcloud data files old → new

**Files:** Docker volume `nc-images-nextcloud-data` on new server

- [ ] **Step 1: Stop cron and app containers on new server (keep DB + Redis running)**

```bash
ssh deployacc@46.224.167.12 "docker stop nc-images-cron nc-images-app"
```

- [ ] **Step 2: Pipe tar of Nextcloud data volume directly old → new**

This streams through your local machine without needing local disk space:

```bash
ssh -i ~/.ssh/id_iohenkies iohenkies@162.55.217.28 \
  "docker run --rm -v <OLD_NEXTCLOUD_VOLUME>:/data alpine tar -czf - -C /data ." \
| ssh deployacc@46.224.167.12 \
  "docker run --rm -i -v nc-images-nextcloud-data:/data alpine sh -c 'rm -rf /data/* /data/.[!.]* && tar -xzf - -C /data'"
```

This clears the new volume completely and replaces it with old content.
Note: may take several minutes depending on data size.

---

### Task 5: Transfer and import PostgreSQL dump

**Files:** PostgreSQL database `nextcloud` on new server

- [ ] **Step 1: Drop and recreate the database on new server**

```bash
ssh deployacc@46.224.167.12 \
  "docker exec nc-images-db psql -U nextcloud -d postgres \
   -c 'DROP DATABASE IF EXISTS nextcloud;' \
   -c 'CREATE DATABASE nextcloud OWNER nextcloud;'"
```

Expected: `DROP DATABASE` then `CREATE DATABASE`

- [ ] **Step 2: Pipe PostgreSQL dump directly old → new**

```bash
ssh -i ~/.ssh/id_iohenkies iohenkies@162.55.217.28 \
  "docker exec <OLD_DB_CONTAINER> pg_dump -U nextcloud nextcloud" \
| ssh deployacc@46.224.167.12 \
  "docker exec -i nc-images-db psql -U nextcloud nextcloud"
```

Expected: many SQL statements, ending without errors. Warnings about existing objects are OK.

---

### Task 6: Fix config.php for new server

**Files:** `config.php` inside `nc-images-nextcloud-data` volume (at `config/config.php`)

The imported config.php contains old DB password and old domain. Fix both.

- [ ] **Step 1: Update dbpassword in config.php**

Replace `NEW_DB_PASS` with the value captured in Task 2:

```bash
ssh deployacc@46.224.167.12 \
  "docker run --rm -v nc-images-nextcloud-data:/data alpine \
   sed -i \"s/'dbpassword' => '[^']*'/'dbpassword' => 'NEW_DB_PASS'/\" \
   /data/config/config.php"
```

- [ ] **Step 2: Verify dbpassword was updated**

```bash
ssh deployacc@46.224.167.12 \
  "docker run --rm -v nc-images-nextcloud-data:/data alpine \
   grep 'dbpassword' /data/config/config.php"
```

Expected: `'dbpassword' => 'NEW_DB_PASS'` (the new password, not the old one).

- [ ] **Step 3: Update trusted_domains and overwrite host in config.php**

```bash
ssh deployacc@46.224.167.12 \
  "docker run --rm -v nc-images-nextcloud-data:/data alpine sh -c \
   \"sed -i \\\"s/old-images\\.cloudpro\\.io/images.cloudpro.io/g\\\" /data/config/config.php\""
```

- [ ] **Step 4: Verify domain is correct in config.php**

```bash
ssh deployacc@46.224.167.12 \
  "docker run --rm -v nc-images-nextcloud-data:/data alpine \
   grep -E 'trusted_domains|overwrite' /data/config/config.php"
```

Expected: all occurrences show `images.cloudpro.io`, none show `old-images.cloudpro.io`.

---

### Task 7: Start containers and run post-migration occ steps

**Files:** none

- [ ] **Step 1: Start app and cron containers on new server**

```bash
ssh deployacc@46.224.167.12 "docker start nc-images-app nc-images-cron"
```

- [ ] **Step 2: Wait for app container to become healthy**

```bash
ssh deployacc@46.224.167.12 \
  "for i in \$(seq 1 30); do \
     STATUS=\$(docker inspect --format='{{.State.Health.Status}}' nc-images-app 2>/dev/null); \
     echo \"Attempt \$i: \$STATUS\"; \
     [ \"\$STATUS\" = 'healthy' ] && break; \
     sleep 5; \
   done"
```

Expected: eventually prints `healthy`.

- [ ] **Step 3: Update data fingerprint**

```bash
ssh deployacc@46.224.167.12 \
  "docker exec nc-images-app php occ maintenance:data-fingerprint"
```

- [ ] **Step 4: Scan all files**

```bash
ssh deployacc@46.224.167.12 \
  "docker exec nc-images-app php occ files:scan --all"
```

- [ ] **Step 5: Disable maintenance mode**

```bash
ssh deployacc@46.224.167.12 \
  "docker exec nc-images-app php occ maintenance:mode --off"
```

Expected: `Maintenance mode disabled`

---

### Task 8: Verify and clean up

- [ ] **Step 1: Test a known shared link on new domain**

Open in browser: `https://images.cloudpro.io/s/kdm2K6odmocoe8r`

Expected: image loads correctly.

- [ ] **Step 2: Verify login works on new server**

Open: `https://images.cloudpro.io` and log in as `iohenkies`.

- [ ] **Step 3: Disable maintenance mode on old server**

```bash
ssh -i ~/.ssh/id_iohenkies iohenkies@162.55.217.28 \
  "docker exec <OLD_APP_CONTAINER> php occ maintenance:mode --off"
```
