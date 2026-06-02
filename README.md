# local-web-stack

Docker-based local PHP development stack with Nginx Proxy support, MySQL, phpMyAdmin, and local email testing.

A clean, lightweight **Laragon alternative** for Windows/macOS/Linux. Drop PHP projects into a shared `www/` folder and open each one at its own local domain (`demo.local`, `pos.local`, `myapp.local`, …) — no per-project config required.

> ⚠️ **Local development only.** This stack is not hardened for production and must not be used to send real email.
>
> 🌐 **This stack uses `.local` domains by default** (configurable via `DOMAIN_SUFFIX` in `.env`). The folder name becomes the subdomain.

---

## 1. What this project is

`local-web-stack` gives you a reusable Docker environment for developing multiple PHP projects side by side. **Any folder you place under `www/` automatically becomes a `.local` site** served at `http://<folder>.local` through a single Nginx + PHP-FPM pair. It connects to an existing **Nginx Proxy** network so it plays nicely with other stacks, and ships with MySQL, phpMyAdmin, and Mailpit for email testing.

## 2. Features

- 🐳 One Docker Compose stack for all your PHP projects
- 🌐 Wildcard local domains — `*.local` routed by subdomain to each project
- 📁 **Folder name = domain.** `www/omar` → `http://omar.local`, automatically
- 🔁 **`public/` fallback:** uses `www/<project>/public` if present, otherwise `www/<project>`
- ♻️ **No rebuild for code changes** — `./www` is volume-mounted, so edits are live instantly
- 🐘 **PHP 8.4 FPM** with common extensions + Composer, git, unzip, curl
- 🗄️ **MySQL 8** with a named volume
- 🧭 **phpMyAdmin** at `http://pma.local`
- 📧 **Mailpit** captures all outgoing mail and shows it at `http://mail.local`
- 🔌 Connects to an existing external **Nginx Proxy** network
- ⚙️ Everything configurable via `.env` — no hardcoded values
- 🧰 Cross-platform hosts-sync + restart helper scripts

## 3. Requirements

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/) (Docker Desktop includes it)
- An existing **Nginx Proxy** container (e.g. [`nginxproxy/nginx-proxy`](https://github.com/nginx-proxy/nginx-proxy) or `jwilder/nginx-proxy`)
- An external Docker **proxy network** that the proxy container is attached to

## 4. Create the external network (if missing)

The stack expects an external network named by `EXTERNAL_PROXY_NETWORK` (default `proxy`). Create it once:

```bash
docker network create proxy
```

Make sure your Nginx Proxy container is connected to this same network (see [Troubleshooting](#17-troubleshooting)).

## 5. Install

```bash
cp .env.example .env
docker compose up -d --build
```

Edit `.env` first if you want to change container names, ports, the database, or the proxy network.

## 6. Adding a new local site

This is the everyday workflow. Create a folder under `www/`, drop in an `index.php`, and run the restart helper:

```bash
mkdir -p www/omar/public
echo "<?php echo 'Hello Omar';" > www/omar/public/index.php
./scripts/restart.sh
```

Open:

```
http://omar.local
```

What happens:

- **Folder name becomes the domain** — `www/omar` → `omar.local`.
- **`public/` fallback** — if `www/omar/public` exists it is the web root; otherwise `www/omar` is used. So `www/omar/index.php` *or* `www/omar/public/index.php` both work.
- **No Docker rebuild required.** Nginx routes any `*.local` host dynamically — you never edit nginx config to add a site.
- **File changes are live** thanks to the `./www:/var/www` volume mount. Editing PHP/HTML shows up immediately on refresh.
- **Restart is only needed** to refresh the hosts file (new domain) and reload nginx/proxy. The `sync-hosts` script adds any missing domains automatically.

## 7. Helper scripts

### `scripts/sync-hosts.sh` (cross-platform)

Scans every folder in `www/`, builds `<folder><DOMAIN_SUFFIX>` for each, adds `PHPMYADMIN_DOMAIN` and `MAILPIT_DOMAIN`, and writes any missing `127.0.0.1 <domain>` entries to the system hosts file (no duplicates). It loads values from `.env` (falling back to `.env.example`) and auto-detects the hosts file path.

### `scripts/restart.sh`

Runs `sync-hosts.sh`, then `docker compose restart`, then prints every project URL plus the phpMyAdmin and Mailpit URLs.

### Running on Windows

Open **Git Bash as Administrator** (admin is required to edit the hosts file), then:

```bash
./scripts/sync-hosts.sh
./scripts/restart.sh
```

or:

```bash
bash scripts/sync-hosts.sh
bash scripts/restart.sh
```

The script detects Git Bash and uses `/c/Windows/System32/drivers/etc/hosts`. On Linux/macOS it uses `/etc/hosts` (run with `sudo`). There is also a Windows-only PowerShell helper, `scripts/add-host.ps1` (run from an elevated PowerShell).

## 8. Manual hosts entries (alternative)

If you prefer not to use the scripts, add entries to your hosts file
(`C:\Windows\System32\drivers\etc\hosts` on Windows, `/etc/hosts` on macOS/Linux):

```
127.0.0.1 demo.local
127.0.0.1 omar.local
127.0.0.1 pma.local
127.0.0.1 mail.local
```

## 9. How project files are tracked in Git

Everything inside `www/` is **ignored by Git** — these are your local projects and must not be pushed to the public repo. The **only** committed project is the demo:

```
www/demo/public/index.php
```

The `.gitignore` rules:

```
www/*
!www/demo/
!www/demo/public/
!www/demo/public/index.php
```

So any folder you add — `www/omar`, `www/client1`, `www/test-app`, … — is ignored automatically and will not show up in `git status`. Place your local projects inside `www/` safely; only `www/demo` ships with the repo as an example.

## 10. MySQL connection (from inside Docker)

Apps running in the PHP container connect to MySQL over the internal network:

```
host=mysql
port=3306
database=app
user=app
password=app
```

## 11. MySQL connection (from the host machine)

Uncomment the MySQL `ports` mapping in `docker-compose.yml` first (see section 15), then connect from a desktop client:

```
host=127.0.0.1
port=3307
user=root
password=root
```

> Port `3307` (from `MYSQL_PORT`) is used on the host to avoid clashing with a local MySQL on `3306`.

## 12. phpMyAdmin

```
http://pma.local
```

Log in with the MySQL credentials (`app` / `app`, or `root` / `root`).

## 13. Mailpit

Web UI:

```
http://mail.local
```

SMTP (from inside Docker):

```
host=mailpit
port=1025
```

No authentication and no TLS — point any app's SMTP settings here. PHP's built-in `mail()` is already routed to Mailpit via `msmtp`, so legacy mail works too.

## 14. Mailpit is for local testing only

Mailpit **catches** outgoing email and displays it in a web UI — it never delivers to real inboxes. Do not use it as a production mail service, and do not configure real credentials in this stack. For production, use a real mail provider (configured outside this repo).

## 15. Optional direct ports

By default services are reachable only through the Nginx Proxy. For quick local testing without the proxy, uncomment the relevant `ports:` lines in `docker-compose.yml`:

| Service     | Variable            | Example mapping     |
|-------------|---------------------|---------------------|
| nginx       | `NGINX_PORT`        | `8080:80`           |
| phpmyadmin  | `PHPMYADMIN_PORT`   | `8081:80`           |
| mysql       | `MYSQL_PORT`        | `3307:3306`         |
| mailpit web | `MAILPIT_WEB_PORT`  | `8025:8025`         |
| mailpit smtp| `MAILPIT_SMTP_PORT` | `1025:1025`         |

Then reach them at e.g. `http://localhost:8080`, `http://localhost:8081`, `http://localhost:8025`.

## 16. How this works with Nginx Proxy

The `nginx`, `phpmyadmin`, and `mailpit` services join the external proxy network and expose `VIRTUAL_HOST` / `VIRTUAL_PORT` environment variables that a common nginx-proxy auto-discovers:

- **nginx** advertises `VIRTUAL_HOST=*.local` and serves every project based on the request's subdomain (preferring `www/<project>/public`).
- **phpmyadmin** advertises `VIRTUAL_HOST=pma.local`.
- **mailpit** advertises `VIRTUAL_HOST=mail.local` on port `8025`.

The proxy terminates the request and forwards it to the right container. Because the wildcard `*.local` is handled at the proxy, the **PHP/MySQL/internal** traffic stays on the private `internal` network.

> **Wildcard local domains:** Browsers still need each `*.local` name to resolve to `127.0.0.1`. The simplest approach is a hosts entry per project (the `sync-hosts.sh` script does this for you). For true wildcard resolution (so any `*.local` works without editing hosts), use a local DNS solution such as **dnsmasq** (macOS/Linux) or **Acrylic DNS Proxy** (Windows) configured to resolve `*.local → 127.0.0.1`.
>
> Note: `.local` is also used by mDNS/Bonjour on some systems. If a domain won't resolve, an explicit hosts entry (which this stack adds) takes precedence and resolves it reliably.

## 17. Troubleshooting

**External network not found**
`network proxy declared as external, but could not be found`. Create it: `docker network create proxy`, or set `EXTERNAL_PROXY_NETWORK` in `.env` to your existing network name.

**Domain not opening**
Confirm the hosts entry exists (`ping demo.local` should resolve to `127.0.0.1`), the project folder is `www/<project>/public` or `www/<project>`, and containers are up (`docker compose ps`). Flush DNS on Windows: `ipconfig /flushdns`.

**Hosts file not updated**
You must edit the hosts file as Administrator/root. Use `scripts/sync-hosts.sh` from an elevated Git Bash (Windows) or with `sudo` (Linux/macOS) — a non-privileged session fails to save and the script reports a permission error.

**MySQL port conflict**
`bind: address already in use` on `3307` (or you have a local MySQL on `3306`). Change `MYSQL_PORT` in `.env`, or leave the MySQL `ports` mapping commented out and connect only from inside Docker.

**Wildcard domains not working**
A hosts file maps exact names, not wildcards — add one entry per project (run `sync-hosts.sh`), or set up dnsmasq / Acrylic DNS for `*.local` (see section 16).

**Nginx Proxy not connected to the same Docker network**
The proxy container must be attached to `EXTERNAL_PROXY_NETWORK`. Check with `docker network inspect proxy` and connect it if missing: `docker network connect proxy <proxy-container-name>`.

**Changes to default.conf not applying**
Restart Nginx: `docker compose restart nginx` (or run `./scripts/restart.sh`).

---

## Project structure

```
local-web-stack/
├─ .env.example
├─ .gitignore
├─ .gitattributes
├─ README.md
├─ docker-compose.yml
├─ nginx/
│  └─ default.conf
├─ php/
│  └─ Dockerfile
├─ scripts/
│  ├─ add-host.ps1
│  ├─ sync-hosts.sh
│  └─ restart.sh
└─ www/
   └─ demo/
      └─ public/
         └─ index.php
```

## License

MIT — use it freely for your local development.
