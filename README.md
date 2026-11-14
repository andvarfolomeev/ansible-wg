# ansible-wg

Ansible playbooks for a personal VPN server on Debian 12:

| Playbook | Roles | What it does |
|---|---|---|
| `setup-wireguard.yml` | `wireguard` | WireGuard server `wg0` with NAT, client `.conf` files generated locally in `clients/` |
| `setup-xray.yml` | `cover_site`, `xray` | Xray VLESS + Reality (Vision and XHTTP on one port) behind an nginx cover site with a Let's Encrypt certificate, per-client monthly traffic limits, weekly geodata updates; share links generated locally in `clients/xray/` |
| `setup-swap.yml` | `swap` | Swap file used only under memory pressure |

All playbooks target the `wg` group of `inventory.ini`.

## Requirements

- Ansible with the `ansible.posix` collection (the full `ansible` package has it)
- `wireguard-tools` locally for `scripts/wg-keygen.sh`, `xray` and `openssl` for `scripts/xray-keygen.sh`
- `devenv shell` provides all of the above

## Quick start

```bash
cp inventory.example.ini inventory.ini
cp peers.example.yml peers.yml
cp xray_clients.example.yml xray_clients.yml   # only for Xray
```

Fill them in, then:

```bash
make wg      # WireGuard
make xray    # Xray + cover site
make swap    # swap file
```

`inventory.ini`, `peers.yml`, `xray_clients.yml` and `clients/` hold server addresses and private keys. They are gitignored, keep them that way.

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

## Testing in Docker

```bash
make docker-build
make docker-run
ansible-playbook -i inventory_docker_example.ini setup-wireguard.yml
make docker-clean
```

The container runs Debian 12 without systemd, so the WireGuard role brings `wg0` up with `wg-quick` directly. Password SSH needs `sshpass`.
