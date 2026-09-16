# AID deployment guide

[简体中文](README.md) | **English**

This directory holds the AID installer and related deployment files. You do not need to clone the repository first. Copy one official command: it saves `aid.sh` from Gitee (GitHub is the fallback), then Bash runs that file. The script reads a signed version manifest, prefers Gitee release tags, switches the whole tree to GitHub if Gitee is unreachable, and builds the backend, admin UI, web UI and updater in a temporary directory on the server. Install or upgrade starts only after the local package passes structure checks. Both Docker and systemd installs can use the script or the admin “one-click online upgrade”.

| Mode | When to use | Notes |
|------|-------------|-------|
| Docker (recommended) | Most users | Middleware runs in containers |
| Manual (systemd) | No containers, or you must use host services | systemd + Nginx; missing host dependencies are prepared by version when allowed |

**`/data/aid` is the main data root**: application files (`app/`), managed installer and Docker files (`installer/`), uploads (`uploadPath/` and private archive `uploadPath-private/`), logs (`logs/`), MySQL/Redis/RocketMQ data, backups (`backups/`), local source-build packages (`packages/`), dependency cache (`build-cache/`) and the manual config file (`aid-deploy.conf`). A complete host backup or migration must also include updater configuration in `/etc/aid-updater/`, updater state in `/var/lib/aid-updater/`, and any configured external middleware or object storage.

## Layout

```text
deploy/
├── aid.sh                         # unified management script (menu + subcommands)
├── build-release-from-source.sh   # tagged source build and local packaging
├── docker/                        # Docker suite
│   ├── docker-compose.yml         # production compose (MySQL/Redis/backend/web/Nginx + optional RocketMQ)
│   ├── docker-compose.middleware.yml # local development middleware only
│   ├── .env.example               # env template (aid.sh writes the real file)
│   ├── nginx/aid.conf             # site config
│   └── rocketmq/                  # Broker configs (broker.conf production / broker-dev.conf development)
├── updater/                       # aid-updater source (Go)
├── install-updater.sh             # updater install helper
├── aid-updater.service            # updater systemd unit
└── aid-updater.config.example.json
```

## One-command install (recommended)

```bash
# First Docker install; wget is used if curl is missing
if command -v curl >/dev/null 2>&1; then curl -fL --retry 3 -o aid-install.sh https://gitee.com/gzxx-2025/aid-studio/raw/master/deploy/aid.sh; elif command -v wget >/dev/null 2>&1; then wget -O aid-install.sh https://gitee.com/gzxx-2025/aid-studio/raw/master/deploy/aid.sh; else echo 'Install curl or wget first'; false; fi && sudo env AID_REMOTE_BOOTSTRAP=1 bash aid-install.sh install
```

The network response is never piped into a shell. The script runs only after `curl`/`wget` writes `aid-install.sh`. `AID_REMOTE_BOOTSTRAP=1` forces that freshly downloaded control logic; an already-installed managed script will not take over. `install` is the automatic entry: first Docker install when nothing is deployed; if AID is already present it checks and upgrades, and does not re-initialize the database. On success it creates `sudo aid` when that name is free. Run `sudo aid default` any time to reprint user/admin URLs (public/private, HTTPS), the database init admin note, and MySQL connection details. Use `sudo aid mysql` for MySQL only.

If Gitee raw files fail, use GitHub:

```bash
if command -v curl >/dev/null 2>&1; then curl -fL --retry 3 -o aid-install.sh https://raw.githubusercontent.com/gzxx-2025/aid-studio/master/deploy/aid.sh; elif command -v wget >/dev/null 2>&1; then wget -O aid-install.sh https://raw.githubusercontent.com/gzxx-2025/aid-studio/master/deploy/aid.sh; else echo 'Install curl or wget first'; false; fi && sudo env AID_REMOTE_BOOTSTRAP=1 bash aid-install.sh install
```

First run does: signed manifest → stable/Beta channel → Gitee tags (whole-tree GitHub fallback) → isolated source build of the three apps plus updater → SHA256 and package-layout checks → managed installer under `/data/aid/installer` → generated config and strong random secrets → hardware check → services and middleware → empty-database init → updater → health checks. A failed fetch or build does not replace running services.

### First confirmation

Config is a required first step. The script writes the real config file and asks you to review, validate and confirm it. Until you confirm, it will not install the environment, pull source, build, initialize the database or start services. Unattended installs must set both `AID_ASSUME_YES=1` and `AID_CONFIG_CONFIRMED=1` so a pipeline cannot go live on defaults.

Writing the config file is not a completed install. If you answer `n` at the final confirm, the next `sudo env AID_REMOTE_BOOTSTRAP=1 bash aid-install.sh install` still follows first-install, not upgrade. The managed installer creates `sudo aid` once it is on disk; deployed state is recorded only after health checks succeed.

> Default channel is `auto`: install stable when one exists; otherwise the latest Beta, with a yellow/red warning. For Beta, add `AID_RELEASE_CHANNEL=beta` to the `sudo env` line. Do not keep production on Beta.

Manual systemd first install uses the same download, then `install-manual`:

```bash
if command -v curl >/dev/null 2>&1; then curl -fL --retry 3 -o aid-install.sh https://gitee.com/gzxx-2025/aid-studio/raw/master/deploy/aid.sh; elif command -v wget >/dev/null 2>&1; then wget -O aid-install.sh https://gitee.com/gzxx-2025/aid-studio/raw/master/deploy/aid.sh; else echo 'Install curl or wget first'; false; fi && sudo env AID_REMOTE_BOOTSTRAP=1 bash aid-install.sh install-manual
```

Config file locations (printed again at the end of install; `/data/aid/config/deployment.json` also records the absolute path):

| Mode | Config file |
|------|-------------|
| Docker | `/data/aid/config/docker.env` (from `deploy/docker/.env.example`) |
| Manual | `/data/aid/aid-deploy.conf` (from `deploy/aid-deploy.conf.example`) |

Empty built-in MySQL passwords and JWT secrets are filled with generated values. External database passwords are never invented.

### Update with the latest remote script

Docker and systemd share one update command. The script reads the current mode from the deployment descriptor:

```bash
if command -v curl >/dev/null 2>&1; then curl -fL --retry 3 -o aid-install.sh https://gitee.com/gzxx-2025/aid-studio/raw/master/deploy/aid.sh; elif command -v wget >/dev/null 2>&1; then wget -O aid-install.sh https://gitee.com/gzxx-2025/aid-studio/raw/master/deploy/aid.sh; else echo 'Install curl or wget first'; false; fi && sudo env AID_REMOTE_BOOTSTRAP=1 bash aid-install.sh update
```

For the Beta channel:

```bash
sudo env AID_REMOTE_BOOTSTRAP=1 AID_RELEASE_CHANNEL=beta bash aid-install.sh update
```

Config merge is “local wins, official only fills missing keys”:

- Docker reads the real config path (default `/data/aid/config/docker.env`). Manual default is `/data/aid/aid-deploy.conf`.
- It loads the current `aid.sh` template, then the target release template, and appends only keys that are completely absent locally.
- Existing values, comments, order, custom keys and empty values are kept.
- A same-directory backup such as `docker.env.bak.20260804-120000` is created only when keys are appended. Mode is `600`.
- Even when the app version is already current, the remote script still fills missing template keys. No missing keys means no rewrite and no backup.

`sudo aid update` still works; it uses the installed managed script. Prefer the remote command when you need the newest install/config logic. Updates still back up the database and the three app artifacts before replacing files or running incremental SQL. While an upgrade or rollback is running, `sudo aid progress` follows stage, percent and logs; `q` leaves the viewer only.

### Automation safety

- Manifests are HTTPS only. Source comes from the official AID GitHub/Gitee trees. All three apps must share one `v<version>` tag. Local packages are still checked for layout, path traversal, special links and embedded script syntax.
- Ed25519 `pkeyutl -rawin` verifies the manifest when OpenSSL supports it; older OpenSSL prints a yellow warning. The online updater always verifies the full signature.
- The script does not silently open firewalls, change DNS, install HTTPS certificates, drop existing databases or import the large official media bundle. Missing or old Docker is installed only after you accept the risk to existing containers.
- Non-install content already under `/data/aid`, version downgrades, database restore and below-recommended hardware default to refuse or extra confirm. Use `AID_ASSUME_YES=1` only in automation that already has an off-host backup.
- Local backups do not replace off-host backups. Copy the database, `/data/aid/uploadPath` and the config files elsewhere before going live.

## `aid.sh` commands

```text
==================== AID deploy ====================
 Mode: docker    Version: 1.0.0    Channel: stable
 Data: /data/aid
------------------------------------------------------
  1) First install (Docker, source build, recommended)
  2) First install (manual systemd, source build)
  3) Check and upgrade to the latest version on this channel (full backup first)
  4) Roll back to a pre-upgrade backup (last 3)
  5) Restart (after config changes)
  6) Stop
  7) Status
  8) Logs
  9) Edit config
 10) Backup now (database + uploads)
 11) Install/repair the online updater
 12) Print login URLs and database init account
 13) Purge AID (delete all AID data)
 14) Print MySQL connection details
 15) Live upgrade/rollback progress (only while a task is running)
  0) Exit
------------------------------------------------------
```

`sudo aid` works from any working directory. Subcommands:

| Command | What it does |
|---------|----------------|
| `sudo aid` | Interactive menu |
| `sudo aid install` | First Docker install, or update if already deployed |
| `sudo aid install-docker` | Force Docker first install |
| `sudo aid install-manual` | Force systemd first install |
| `sudo aid status` | Mode, version, data directory; `docker compose ps` or systemd/`Nginx`/updater status; disk use under `/data/aid` |
| `sudo aid logs` | Follow backend, error file, web/Nginx, MySQL or updater logs (`Ctrl+C` stops follow). External MySQL logs stay on that server |
| `sudo aid update` | Upgrade on the saved channel; refuses automatic downgrade; full backup first |
| `sudo aid progress` | Live upgrade/rollback progress; no-op message when idle |
| `sudo aid backup` | Database dump, `uploadPath` tarball and config copies under `/data/aid/backups/<timestamp>/`; deletes those dated dirs older than 7 days |
| `sudo aid restart` / `sudo aid stop` | Restart or stop |
| `sudo aid default` | User/admin URLs (HTTP/HTTPS, public/private) and MySQL details. Root only. Does not recover a changed admin password |
| `sudo aid mysql` | MySQL host/port/database/user/password (and built-in root password) |
| `sudo aid config` | Open the real config file in `vi` (or `$EDITOR`) and optionally restart |
| `sudo aid rollback` | Restore app files from one of the last 3 pre-upgrade backups; database restore is opt-in |
| `sudo aid setup-updater` | Repair the updater from the signed manifest |
| `sudo aid uninstall` | Interactive keep-data vs purge |
| `sudo aid uninstall --keep` | Stop and remove AID services/Nginx/updater/`sudo aid`; keep `DATA_ROOT`. Confirm with `y` |
| `sudo aid uninstall --purge` or `sudo aid uninstall-all` | Also delete `DATA_ROOT` and owned built-in middleware data. Type `DELETE-AID`. `AID_ASSUME_YES` cannot skip this |

Menu item 13 goes straight to purge (no keep-data choice).

If you used a custom `AID_DATA_ROOT`, `sudo aid` infers it from the managed installer path and marked systemd units. Several candidates: the command refuses to guess and asks for an explicit `AID_DATA_ROOT`.

Purge only removes resources with **current-install ownership** and re-checks before reporting success. It does not uninstall shared Docker/JDK/Nginx/Git, and it does not delete external MySQL, Redis, RocketMQ or object-storage data.

`AID_ASSUME_YES=1` skips deploy/upgrade confirms. Do not leave it set on an interactive production host.

## Hardware

| Install | Minimum | Recommended |
|---------|---------|-------------|
| Local Docker, no RocketMQ | 2 CPU / 4 GB RAM / 40 GB disk | 4 CPU / 8 GB / 100 GB+ |
| Local Docker with RocketMQ | 4 CPU / 4 GB / 40 GB | 6 CPU / 12 GB / 100 GB+ |
| Local systemd, middleware on the same host | 2 CPU / 4 GB / 40 GB | 4 CPU / 8 GB / 100 GB+ |
| Local systemd with RocketMQ | 4 CPU / 4 GB / 40 GB | 6 CPU / 12 GB / 100 GB+ |

`aid.sh` prints current vs minimum vs recommended. Below either line it warns only; `y` continues, `n` cancels. 40 GB is program + database + logs. Put media on object storage.

## Docker deploy

### Prerequisites

- Linux, recommended 4 CPU / 8 GB / 100 GB+
- `curl`, `tar` (host Git is used when present; otherwise an isolated Git container)
- Docker Engine 24+ and Compose plugin v2.20+; if missing, the script asks whether to install from a probed Tsinghua/Aliyun/official Docker CE repo

Docker one-click install uses MySQL 5.7, so the host must be `x86_64`. Official MySQL 5.7 images have no ARM64 build; the script stops on ARM64 instead of changing the major version.

Missing or too-old Docker: the script prints the change set and the risk to existing containers, default answer `no`. Only after `yes` does it use HTTPS repos, check the Docker GPG fingerprint, install Engine/Compose and start Docker.

### Docker steps

Use the one-command install above. It builds from a version tag, extracts the deploy kit, and writes `/data/aid/config/docker.env` from `.env.example`. Defaults are built-in MySQL + Redis, RocketMQ off, HTTPS off. Change ports, HTTPS, external MySQL/Redis or RocketMQ in that file, then `sudo aid restart`.

Docker mode does not require host Git, JDK, Node, Go, FFmpeg, Nginx or Redis. Host needs Docker Engine 24+ and Compose v2.

`DEPENDENCY_INSTALL_MODE`:

| Value | Docker | Manual systemd |
|-------|--------|----------------|
| `auto` (default) | Missing images download and verify by `DEPENDENCY_REGION`; Docker itself still needs a separate confirm | Downloads isolated Oracle JDK 17.0.8, Nginx 1.30.4, Node 22.22.0, Maven 3.9.9, Go 1.22.12, MySQL 5.7.44, Redis 8.0.5 and AID FFmpeg 8.1.2 as needed |
| `manual` | Stops and prints the exact `docker pull` | Lists missing or wrong versions; does not change the system |

AID does not replace the system FFmpeg. Docker Nginx is not written to host `/etc/nginx`: managed HTTP config is `/data/aid/installer/deploy/docker/nginx/aid.conf`, mounted read-only. Put custom reverse-proxy rules outside AID so upgrades do not wipe them.

URLs after install (real values from `sudo aid default`; the script fills public/private IPv4, it does not print a “server IP” placeholder):

- User HTTP: `http://<public-or-private-ipv4>:HTTP_PORT/`
- Admin HTTP: `http://<public-or-private-ipv4>:ADMIN_PORT/<random-access-code>`
- Init admin account from `sql/aid-init.sql` is `admin / admin123`. Change it after first login. `sudo aid default` never recovers a later password.

No domain is required for HTTP. Keep `HTTP_PORT` and `ADMIN_PORT`. Docker: `COMPOSE_PROFILES=mysql,redis` (do not add `https`). Manual: `HTTPS_ENABLED=false`. Do not set `HTTP_PORT=443`; that is still plaintext HTTP.

### Docker HTTPS (optional profile)

`HTTP_PORT=443` does not enable TLS. Real HTTPS uses the `https` profile: two different hostnames, one SAN or wildcard certificate covering both.

Add two `A` records (for example `www.example.com` and `admin.example.com`) to the server public IPv4. DNS does not issue certificates and does not close the IP/HTTP listeners. Keep `HTTP_PORT` and `ADMIN_PORT` unless you add redirects in a firewall or a separate proxy.

```bash
mkdir -p /data/aid/config/ssl
cp /secure-source/fullchain.pem /data/aid/config/ssl/fullchain.pem
cp /secure-source/privkey.pem /data/aid/config/ssl/privkey.pem
chmod 600 /data/aid/config/ssl/fullchain.pem /data/aid/config/ssl/privkey.pem
```

```dotenv
COMPOSE_PROFILES=mysql,redis,https
HTTPS_PORT=443
HTTPS_PUBLIC_DOMAIN=www.example.com
HTTPS_ADMIN_DOMAIN=admin.example.com
HTTPS_CERT_PATH=/data/aid/config/ssl/fullchain.pem
HTTPS_KEY_PATH=/data/aid/config/ssl/privkey.pem
```

Certificate files must live under `DATA_ROOT/config/ssl` and must not be symlinks. User URL is `https://www.example.com/`; admin is `https://admin.example.com/<random-access-code>`. After renewal, overwrite the two files and `sudo aid restart`. Without the `https` profile the HTTPS container is not started and 443 is not used.

### MySQL, Redis, RocketMQ and external middleware

**MySQL.** Default `COMPOSE_PROFILES=mysql,redis` starts built-in MySQL 5.7. For an external MySQL 5.7, drop `mysql` from the profiles:

```dotenv
COMPOSE_PROFILES=redis
DB_HOST=10.0.0.20
DB_PORT=3306
DB_NAME=aid
DB_USERNAME=aid
DB_PASSWORD=<your-mysql-password>
```

The address must be reachable from both AID app containers and the temporary DB client. On the Docker host use `host.docker.internal`; remote DBs should use a private IP or internal DNS. Do not use loopback for Docker external MySQL. The external account needs create-table, index, DML, transaction, view, trigger and backup/restore rights. If it cannot create databases, have a DBA create a UTF-8 MB4 database first.

- Fresh empty target: after confirming MySQL 5.7, the script imports that version’s init and extension SQL.
- Switching from built-in to external: migrate data first. An old built-in container plus an empty external database is refused so the app cannot come up with no data.
- After the external DB passes connect, version and AID core-table checks, `aid-mysql` is stopped and removed. `${DATA_ROOT}/mysql-data` is kept for a manual fallback. Later compose/restart/upgrade will not start built-in MySQL again.
- Backup, restore and incremental SQL use a one-shot `mysql:5.7` client container. That is not a database server.

Do not keep the `mysql` profile while pointing `DB_HOST` elsewhere; install and updater reject that. The admin “project upgrade config” page can switch too, but only to an already-migrated external DB that has AID core tables.

Built-in and local manual MySQL do not publish 3306 to the internet. Prefer an SSH tunnel (`127.0.0.1` plus `MYSQL_PORT` / `DB_PORT`). Do not bind Compose MySQL to `0.0.0.0` or open security-group 3306 to the world. For external MySQL, connect to the provider address, not the AID host.

**Redis.** Default profiles include `redis`. For an external instance, drop `redis` and set `REDIS_HOST` / `REDIS_PORT` / `REDIS_USERNAME` / `REDIS_PASSWORD` / `REDIS_DATABASE`. Username and password may be empty. Redis 6+ ACL uses both; classic `requirepass` uses password only. Do not use `127.0.0.1` from Docker; use a container-reachable private IP or DNS.

**RocketMQ** (examples also live as comments in the env file):

- **Off (default):** `ROCKETMQ_ENABLED=false`. Local task mode; all product features still work; MQ code is not loaded.
- **Built-in containers:** `COMPOSE_PROFILES=mysql,redis,mq` and `ROCKETMQ_ENABLED=true`. Tune `MQ_BROKER_JAVA_OPTS` / `MQ_NAMESRV_JAVA_OPTS` (image default 8G heap is already overridden to 1G / 256m). If both `ROCKETMQ_ACCESS_KEY` and `ROCKETMQ_SECRET_KEY` are set, the built-in Broker turns ACL on; leave both empty only on a trusted private network. Then enable MQ dispatch in admin “message queue config” and test the connection.
- **NameServer on the Docker host:** omit `mq` from `COMPOSE_PROFILES`, set `ROCKETMQ_ENABLED=true` and `ROCKETMQ_NAMESERVER=host.docker.internal:9876`. `127.0.0.1` / `localhost` inside the app container is the container itself; install and updater reject that.
- **Remote instance:** `ROCKETMQ_ENABLED=true` and `ROCKETMQ_NAMESERVER=192.168.1.10:9876`. No local MQ container. Fill ACL keys only when the remote Broker uses ACL.

External MySQL + Redis + RocketMQ with built-in HTTPS is `COMPOSE_PROFILES=https` — do not add `mysql` / `redis` / `mq`. RocketMQ ACL values are letters and digits only. The admin UI shows “configured”; real secrets stay in the mode-600 runtime config, not in git or templates.

Install, update and `sudo aid restart` probe the external NameServer from a temporary AID container network, not only from the host. Probe failure prints the real config path and the four repair shapes (off, built-in, host, other server). A reachable NameServer is not enough: external `brokerIP1` must be an address AID containers can reach, not `127.0.0.1`.

Built-in Broker flush: `ROCKETMQ_FLUSH_DISK_TYPE` is `ASYNC_FLUSH` (default) or `SYNC_FLUSH`. AID never remotely rewrites an external Broker’s `flushDiskType`.

External MySQL, Redis and RocketMQ are connectivity and auth checks only. The installer will not install same-named host services or overwrite the provider config.

### Docker backups

`sudo aid backup` (menu 10) writes a full database dump, uploads and deploy config to `/data/aid/backups/<timestamp>/`, then deletes those dated directories older than 7 days.

```bash
# daily example — keep the log path on the host, not in this repository
# 0 3 * * * /usr/local/bin/aid backup >> /var/log/aid-backup.log 2>&1
```

Restore overwrites live data. Confirm first. Docker example:

```bash
gunzip < /data/aid/backups/<timestamp>/db.sql.gz | docker exec -i aid-mysql mysql -uroot -p'<root-password>' aid
tar -xzf /data/aid/backups/<timestamp>/uploadPath.tar.gz -C /data/aid
sudo aid restart
```

One-click upgrade also takes its own backup (including the database) first.

## Manual systemd deploy

```bash
if command -v curl >/dev/null 2>&1; then curl -fL --retry 3 -o aid-install.sh https://gitee.com/gzxx-2025/aid-studio/raw/master/deploy/aid.sh; elif command -v wget >/dev/null 2>&1; then wget -O aid-install.sh https://gitee.com/gzxx-2025/aid-studio/raw/master/deploy/aid.sh; else echo 'Install curl or wget first'; false; fi && sudo env AID_REMOTE_BOOTSTRAP=1 bash aid-install.sh install-manual
```

The script writes `/data/aid/aid-deploy.conf`. New local MySQL gets generated root and app passwords. Existing or external MySQL asks for the real password (no echo) and checks it immediately. Empty `TOKEN_SECRET` is generated.

Manual mode never uses Docker for the source build (`AID_SOURCE_BUILD_MODE=host`). RocketMQ is never auto-installed; if you enable it, at least one external NameServer must be reachable.

Local MySQL missing: isolated Oracle MySQL 5.7.44 and `aid-mysql.service`. Existing 5.7 is validated and skipped. Other majors stop the install. Local Redis missing: Redis 8.0.5 and `aid-redis.service`. External Redis is check-only.

After config edits, `sudo aid restart` re-checks versions and connectivity and skips components that already match.

### Manual HTTPS

Keep `HTTPS_ENABLED=false` until DNS and certificates are ready. Copy certs to `/data/aid/config/ssl/fullchain.pem` and `privkey.pem`, then:

```dotenv
HTTPS_ENABLED=true
HTTPS_PORT=443
HTTPS_PUBLIC_DOMAIN=www.example.com
HTTPS_ADMIN_DOMAIN=admin.example.com
HTTPS_CERT_PATH=/data/aid/config/ssl/fullchain.pem
HTTPS_KEY_PATH=/data/aid/config/ssl/privkey.pem
```

`sudo aid restart` regenerates the Nginx site, runs `nginx -t`, then reloads. Failed validation restores the previous site. Certificates must be real files under `DATA_ROOT/config/ssl`, not symlinks.

### Manual RocketMQ

AID does not install RocketMQ on systemd hosts. Start NameServer/Broker yourself (override the distro’s large default heap with `JAVA_OPT_EXT`), then set `ROCKETMQ_ENABLED=true` and `ROCKETMQ_NAMESERVER=127.0.0.1:9876` in `aid-deploy.conf`, restart, and enable MQ dispatch in the admin UI.

## Online updater

First install of either mode installs the updater. Docker runs `aid-updater` in compose (uses `docker.sock`; SQL via `docker exec` or a throwaway MySQL 5.7 client). Manual runs `aid-updater.service`. Config is `/etc/aid-updater/config.json`; data is `/var/lib/aid-updater/`.

Repair:

```bash
sudo aid setup-updater
# if sudo aid was never created:
sudo bash /data/aid/installer/deploy/aid.sh setup-updater
```

`sudo aid update` runs the same updater check before replacing the app.

Admin “one-click upgrade”: signed version check → same-tag source build → package check → backup → incremental SQL while up → stop → replace artifacts → start → health check; failure rolls back. `aid_schema_history` skips already-successful scripts. Duplicate upgrade/rollback submissions are blocked. Watch with `sudo aid progress`.

If both the updater and the app have new versions, the app upgrade is refused until the updater is current.

## Local development middleware

Not for production:

```bash
cd deploy/docker
docker compose -f docker-compose.middleware.yml up -d
docker compose -f docker-compose.middleware.yml --profile mq up -d
```

## Must-do after install

- Change the init admin password.
- For production HTTPS, use the `https` profile or `HTTPS_ENABLED=true`, keep certs in the restricted directory, and open only the ports you need.
- Back up the printed config file (`/data/aid/config/docker.env` or `/data/aid/aid-deploy.conf`, mode 600) off the host. Do not paste passwords, tokens or API keys into issues or this repository.
