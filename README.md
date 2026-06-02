# local-web-stack

Docker-based local PHP development stack with Nginx Proxy support, MySQL, phpMyAdmin, and local email testing.

A clean, lightweight **Laragon alternative** for Windows/macOS/Linux. Drop PHP projects into a shared `www/` folder and open each one at its own local domain (`demo.test`, `pos.test`, `myapp.test`, …) — no per-project config required.

> ⚠️ **Local development only.** This stack is not hardened for production and must not be used to send real email.

---

## 1. What this project is

`local-web-stack` gives you a reusable Docker environment for developing multiple PHP projects side by side. Each folder under `www/<project>/public` is automatically served at `http://<project>.test` through a single Nginx + PHP-FPM pair. It connects to an existing **Nginx Proxy** network so it plays nicely with other stacks, and ships with MySQL, phpMyAdmin, and Mailpit for email testing.

## 2. Features

- 🐳 One Docker Compose stack for all your PHP projects
- 🌐 Wildcard local domains — `*.test` routed by subdomain to `www/<project>/public`
- 🐘 **PHP 8.4 FPM** with common extensions + Composer, git, unzip, curl
- 🗄️ **MySQL 8** with a named volume
- 🧭 **phpMyAdmin** at `http://pma.test`
- 📧 **Mailpit** captures all outgoing mail and shows it at `http://mail.test`
- 🔌 Connects to an existing external **Nginx Proxy** network
- ⚙️ Everything configurable via `.env` — no hardcoded values
- 🧩 Laravel-style `try_files` fallback (works for plain PHP and frameworks)

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

Make sure your Nginx Proxy container is connected to this same network (see [Troubleshooting](#16-troubleshooting)).

## 5. Install

```bash
cp .env.example .env
docker compose up -d --build
```

Edit `.env` first if you want to change container names, ports, the database, or the proxy network.

## 6. Add hosts entries on Windows (manual)

Local `*.test` domains don't resolve automatically. Add them to your hosts file
(`C:\Windows\System32\drivers\etc\hosts`) — edit it as Administrator:

```
127.0.0.1 demo.test
127.0.0.1 pma.test
127.0.0.1 mail.test
```

On macOS/Linux the file is `/etc/hosts` (use `sudo`).

## 7. Use the helper script (Windows)

Instead of editing the hosts file by hand, run the included helper in an **Administrator** PowerShell:

```powershell
./scripts/add-host.ps1
```

It checks for admin rights, adds `demo.test`, `pma.test`, and `mail.test`, and skips entries that already exist. Add more domains by editing the `$Domains` array at the top of the script.

## 8. Add a new PHP project

1. Create the project folder with a `public/` web root:

   ```
   www/project-name/public/index.php
   ```

2. Add a hosts entry (or add the domain to `scripts/add-host.ps1` and re-run it):

   ```
   127.0.0.1 project-name.test
   ```

3. Open it:

   ```
   http://project-name.test
   ```

No Nginx or Compose changes are needed — routing is automatic based on the subdomain.

## 9. MySQL connection (from inside Docker)

Apps running in the PHP container connect to MySQL over the internal network:

```
host=mysql
port=3306
database=app
user=app
password=app
```

## 10. MySQL connection (from the host machine)

Uncomment the MySQL `ports` mapping in `docker-compose.yml` first (see section 14), then connect from a desktop client:

```
host=127.0.0.1
port=3307
user=root
password=root
```

> Port `3307` (from `MYSQL_PORT`) is used on the host to avoid clashing with a local MySQL on `3306`.

## 11. phpMyAdmin

```
http://pma.test
```

Log in with the MySQL credentials (`app` / `app`, or `root` / `root`).

## 12. Mailpit

Web UI:

```
http://mail.test
```

SMTP (from inside Docker):

```
host=mailpit
port=1025
```

No authentication and no TLS — point any app's SMTP settings here. PHP's built-in `mail()` is already routed to Mailpit via `msmtp`, so legacy mail works too. The demo page has a **Send a test email** button.

## 13. Mailpit is for local testing only

Mailpit **catches** outgoing email and displays it in a web UI — it never delivers to real inboxes. Do not use it as a production mail service, and do not configure real credentials in this stack. For production, use a real mail provider (configured outside this repo).

## 14. Optional direct ports

By default services are reachable only through the Nginx Proxy. For quick local testing without the proxy, uncomment the relevant `ports:` lines in `docker-compose.yml`:

| Service     | Variable            | Example mapping     |
|-------------|---------------------|---------------------|
| nginx       | `NGINX_PORT`        | `8080:80`           |
| phpmyadmin  | `PHPMYADMIN_PORT`   | `8081:80`           |
| mysql       | `MYSQL_PORT`        | `3307:3306`         |
| mailpit web | `MAILPIT_WEB_PORT`  | `8025:8025`         |
| mailpit smtp| `MAILPIT_SMTP_PORT` | `1025:1025`         |

Then reach them at e.g. `http://localhost:8080`, `http://localhost:8081`, `http://localhost:8025`.

## 15. How this works with Nginx Proxy

The `nginx`, `phpmyadmin`, and `mailpit` services join the external proxy network and expose `VIRTUAL_HOST` / `VIRTUAL_PORT` environment variables that a common nginx-proxy auto-discovers:

- **nginx** advertises `VIRTUAL_HOST=*.test` and serves every `www/<project>/public` based on the request's subdomain.
- **phpmyadmin** advertises `VIRTUAL_HOST=pma.test`.
- **mailpit** advertises `VIRTUAL_HOST=mail.test` on port `8025`.

The proxy terminates the request and forwards it to the right container. Because the wildcard `*.test` is handled at the proxy, the **PHP/MySQL/internal** traffic stays on the private `internal` network.

> **Wildcard local domains:** Browsers still need each `*.test` name to resolve to `127.0.0.1`. The simplest approach is a hosts entry per project (section 6 / the helper script). For true wildcard resolution (so any `*.test` works without editing hosts), use a local DNS solution such as **dnsmasq** (macOS/Linux) or **Acrylic DNS Proxy** (Windows) configured to resolve `*.test → 127.0.0.1`.

## 16. Troubleshooting

**External network not found**
`network proxy declared as external, but could not be found`. Create it: `docker network create proxy`, or set `EXTERNAL_PROXY_NETWORK` in `.env` to your existing network name.

**Domain not opening**
Confirm the hosts entry exists (`ping demo.test` should resolve to `127.0.0.1`), the project folder is `www/<project>/public`, and containers are up (`docker compose ps`). Flush DNS on Windows: `ipconfig /flushdns`.

**Hosts file not updated**
You must edit the hosts file as Administrator. Use `scripts/add-host.ps1` from an elevated PowerShell — a non-admin session silently fails to save.

**MySQL port conflict**
`bind: address already in use` on `3307` (or you have a local MySQL on `3306`). Change `MYSQL_PORT` in `.env`, or leave the MySQL `ports` mapping commented out and connect only from inside Docker.

**Wildcard domains not working**
A hosts file maps exact names, not wildcards — add one entry per project, or set up dnsmasq / Acrylic DNS for `*.test` (see section 15).

**Nginx Proxy not connected to the same Docker network**
The proxy container must be attached to `EXTERNAL_PROXY_NETWORK`. Check with `docker network inspect proxy` and connect it if missing: `docker network connect proxy <proxy-container-name>`.

**Changes to default.conf not applying**
Restart Nginx: `docker compose restart nginx`.

---

## Project structure

```
local-web-stack/
├─ .env.example
├─ .gitignore
├─ README.md
├─ docker-compose.yml
├─ nginx/
│  └─ default.conf
├─ php/
│  └─ Dockerfile
├─ scripts/
│  └─ add-host.ps1
└─ www/
   └─ demo/
      └─ public/
         └─ index.php
```

## License

MIT — use it freely for your local development.
