# ansible-wg

Ansible playbooks for a personal VPN server on Debian 12 or Ubuntu 24.04:

| Playbook | Roles | What it does |
|---|---|---|
| `setup-wireguard.yml` | `wireguard` | WireGuard server `wg0` with NAT, client `.conf` files generated locally in `clients/` |
| `setup-xray.yml` | `cover_site`, `xray` | Xray VLESS + Reality (Vision and XHTTP on one port) behind an nginx cover site with a Let's Encrypt certificate, per-client monthly traffic limits, weekly geodata updates; share links generated locally in `clients/xray/` |
| `setup-swap.yml` | `swap` | Swap file used only under memory pressure |
| `setup-fialka.yml` | `docker`, `fialka` | [fialka](https://github.com/andvarfolomeev/tinkering) secret links service with PostgreSQL in Docker Compose, HTTPS on 443 behind Xray Reality and nginx with a Let's Encrypt certificate |

All playbooks target the `wg` group of `inventory.ini`.

## Requirements

- Ansible with the `ansible.posix`, `community.docker` and `community.general` collections (the full `ansible` package has them)
- `wireguard-tools` locally for `scripts/wg-keygen.sh`, `xray` and `openssl` for `scripts/xray-keygen.sh`
- `gitleaks` and `trufflehog` for `make secrets`
- `devenv shell` provides all of the above

## Quick start

```bash
cp inventory.example.ini inventory.ini
cp peers.example.yml peers.yml
cp xray_clients.example.yml xray_clients.yml   # only for Xray
cp fialka.example.yml fialka.yml               # only for fialka
```

Fill them in, then:

```bash
make wg      # WireGuard
make xray    # Xray + cover site
make swap    # swap file
make fialka  # fialka
```

`inventory.ini`, `peers.yml`, `xray_clients.yml`, `fialka.yml` and `clients/` hold server addresses and private keys. They are gitignored, keep them that way.

`make secrets` checks git history and the index for leaked keys and secret files: `scripts/secrets-check.sh`, then gitleaks (config in `.gitleaks.toml`) and trufflehog without verification, so nothing is sent out. Tools come from `devenv shell`.

## WireGuard

`peers.yml` holds the server `interface` and one `peers` entry per device:

```bash
./scripts/wg-keygen.sh 2   # two peer entries with fresh keys, also copied to the clipboard
```

Give every peer a unique `/32` inside `interface.address`, re-run `make wg`, and import `clients/<name>.conf` on the device. Peer changes are applied with `wg syncconf` without dropping connected clients. Changes to the server address, MTU or NAT rules need `systemctl restart wg-quick@wg0` on the server.

Role settings live in `roles/wireguard/defaults/main.yml`. `wireguard_nat_interface` defaults to the interface of the server's default route; set it explicitly if outbound traffic leaves through another one, NAT does not work with the wrong one.

## Xray

`./scripts/xray-keygen.sh --new [count]` prints a complete `xray_clients.yml` with a fresh Reality key pair, `./scripts/xray-keygen.sh [name] [count]` prints new client entries to append.

Before the first run:

- point `xray_server.domain` at the server with a DNS-only A record, the playbook checks it
- open ports 80 (certificate issuance) and `xray_server.port` (443 by default)

Reality forwards connections without a valid client key to the cover site on `127.0.0.1:8444`, so probes see an ordinary HTTPS blog. Share links for every client and profile are written to `clients/xray/all_clients.txt`.

Traffic limits: `xray_monthly_limit_gb` in `roles/xray/defaults/main.yml`, or `monthly_limit_gb` on a client. Domains and IPs the server refuses to carry (`xray_blocked_domains`, `xray_blocked_ips`, `xray_blocked_ads`) are set there too.

Per-client traffic for the month, limits and last activity are shown on `http://10.0.0.1/`, reachable only with WireGuard connected: nginx listens on the `wg0` address only. Each client expands into the sites it connected to this month, counted from the Xray access log in the journal. Xray has no per-site byte counters, so sites are ranked by connections, and clients that resolve names themselves show up as IPs. The page is refreshed every 5 minutes. Change it, or disable it and the site collection with an empty address, via `xray_dashboard_address`. Xray clients cannot reach it, or any other private address of the server.

The role's tasks are tagged `install`, `config`, `quota`, `geodata`, `dashboard` and `links`, to run one part: `make xray ARGS="--tags quota"`.

## fialka

The image is built by the Release workflow in tinkering and pushed to GHCR as
`ghcr.io/andvarfolomeev/tinkering/fialka-service-api:<version>-<commit>`. Put that tag into `fialka_image_tag`
in `fialka.yml` and run `make fialka`; a new tag recreates only the app container, the database stays in the
`pgdata` volume.

Before the first run:

- run `make xray`: fialka needs the PROXY protocol between Reality and the cover site, the playbook checks it
- point `fialka_domain` at the server with a DNS-only A record, the playbook checks it
- make the GHCR package public, or set `fialka_registry_username` and `fialka_registry_password` to a token
  with `read:packages`

fialka is served on `https://<fialka_domain>` through Xray, which owns port 443:

```
browser ─443─▶ Xray Reality ─(no client key, PROXY header)─▶ nginx 127.0.0.1:8444 ─(SNI)─▶ fialka 127.0.0.1:8090
```

Reality forwards every connection without a client key to the cover site listener, and with `xver: 1` it
prepends the client address in a PROXY protocol header. nginx picks the fialka server by SNI, terminates TLS
with the fialka certificate and sets `X-Forwarded-For` from that header, overwriting what the client sent.
fialka trusts `X-Forwarded-For` from 127.0.0.1 only and limits link creation per client address. nginx answers
404 for `/actuator`, health probes are checked on `127.0.0.1:8090` from the server. nginx on port
80 answers ACME challenges for the domain and redirects everything else to HTTPS; renewals reload nginx through
the cover site deploy hook.

The cover site listener now accepts only connections with a PROXY header, which Xray sends. Anything that
talks to `127.0.0.1:8444` directly has to send one too.

Docker runs with `"iptables": false`, so it never touches the WireGuard NAT and FORWARD rules. Both containers
use the host network and listen on 127.0.0.1 only: PostgreSQL on 5433, fialka on 8090.
The image is linux/amd64 only, the playbook stops on other architectures.

PostgreSQL takes `fialka_db_password` only when it creates the `pgdata` volume, a later change in `fialka.yml`
reaches fialka but not the database. Change it in the database first, then run `make fialka`:

```bash
docker compose -f /opt/fialka/compose.yaml exec postgres psql -U fialka -d fialka -c '\password fialka'
```

Role settings live in `roles/fialka/defaults/main.yml`: the ports, the rate limit and extra JVM flags
(`fialka_java_options`, e.g. `-Xmx256m`).

## Testing in Docker

```bash
make docker-build
make docker-run
ansible-playbook -i inventory_docker_example.ini setup-wireguard.yml
make docker-clean
```

The container runs Debian 12 without systemd, so the WireGuard role brings `wg0` up with `wg-quick` directly. `setup-fialka.yml` does not run there: Docker and nginx need systemd. Password SSH needs `sshpass`.
