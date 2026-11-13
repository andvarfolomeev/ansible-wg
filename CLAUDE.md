# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Does

Ansible playbooks for a personal VPN server on Debian 12: WireGuard (`setup-wireguard.yml`), Xray VLESS + Reality behind an nginx cover site (`setup-xray.yml`), and a swap file (`setup-swap.yml`). Client configs and share links are generated locally into `clients/`. All playbooks target the `wg` inventory group.

## Running the Playbooks

```bash
# Deploy to real server (uses inventory.ini)
make wg        # also: make xray, make swap
make xray ARGS="--tags quota"   # extra ansible-playbook flags; xray tags: install, config, quota, geodata, links
# or directly:
ansible-playbook -i inventory.ini setup-wireguard.yml --ask-become-pass

# Deploy to Docker test container
ansible-playbook -i inventory_docker_example.ini setup-wireguard.yml
```

## Docker Testing Environment

```bash
make docker-build   # Build ansible-wg-test image
make docker-run     # Start privileged container (SSH on port 2222; privileged so sysctl and wg0 work)
make docker-info    # Print SSH connection details
make docker-clean   # Remove container and image
```

The Docker container uses `debian:12` (same as production) with SSH user `ansible`/`ansible123`, also the become password. The credentials live in `Makefile` (passed to the Dockerfile as build args) and `inventory_docker_example.ini` — keep them in sync. Password SSH needs `sshpass` (in `devenv.nix`). The container has no systemd, so the role takes its `wg-quick` fallback path there.

## Generating New Keys

```bash
./scripts/wg-keygen.sh [N]              # N WireGuard peer entries for peers.yml (default: 1)
./scripts/xray-keygen.sh --new [count]  # complete xray_clients.yml with a fresh Reality key pair
./scripts/xray-keygen.sh [name] [count] # client entries to append to xray_clients.yml
```

Output is ready to paste and is also copied to clipboard if a clipboard tool is available.

## Architecture

```
peers.yml              — WireGuard: server interface + all client peers (gitignored, see peers.example.yml)
xray_clients.yml       — Xray: server settings + clients (gitignored, see xray_clients.example.yml)
inventory.ini          — Production host, wg group (gitignored, see inventory.example.ini)
setup-wireguard.yml    — loads peers.yml, runs wireguard
setup-xray.yml         — loads xray_clients.yml, runs cover_site then xray
setup-swap.yml         — runs swap
roles/wireguard/
  defaults/main.yml    — Role defaults (NAT interface, DNS, keepalive, allowed IPs, MTU)
  tasks/main.yml       — Install packages → write server.conf → enable IP forwarding → start WG → generate client configs locally
  handlers/main.yml    — Reload WireGuard: `wg syncconf` on wg0.conf changes, no client drops (Address/MTU/PostUp changes need a manual restart)
  templates/
    server.conf.j2     — wg0.conf: Interface + [Peer] for every entry in peers[]
    client.conf.j2     — Per-peer client config (iterated over peers[])
roles/cover_site/      — nginx static site on 127.0.0.1:8444 with a Let's Encrypt cert; Reality target for unauthenticated connections
roles/xray/            — Xray VLESS + Reality; tasks split by tag: install, config, quota (xray-quota timer, per-client monthly limits),
                         geodata (weekly geosite/geoip refresh for the block lists), links (share links into clients/xray/)
roles/swap/            — Swap file with low swappiness
clients/               — Generated client configs (created locally via delegate_to: localhost)
```

### Data Flow

`peers.yml` defines `interface` (server keys, endpoint, address) and `peers[]` (one entry per device). The role renders `server.conf.j2` onto the remote host and `client.conf.j2` locally for each peer. Client configs reference `interface.public_key` and `interface.endpoint` from `peers.yml`.

### Key Variables

| Variable | Where set | Purpose |
|---|---|---|
| `wireguard_nat_interface` | `defaults/main.yml` | Outbound NIC for iptables MASQUERADE (default `eth0`) |
| `wireguard_allowed_ips` | `defaults/main.yml` | AllowedIPs in client configs (default routes all traffic) |
| `wireguard_dns_servers` | `defaults/main.yml` | DNS in client configs |
| `client_configs_dir` | playbook / defaults | Local output dir for client `.conf` files |

### Adding a WireGuard Peer

Pick the next free `/32` in `10.0.0.0/24` (the server is `.1`), add the entry to `peers.yml`, and re-run the playbook to update `wg0.conf` and regenerate all client configs.

## Secrets

`peers.yml`, `xray_clients.yml`, `inventory.ini` and `clients/` hold real private keys and server addresses. They are gitignored and have never been committed — keep it that way, never `git add -f` them, and avoid printing their contents.
