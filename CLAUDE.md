# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Does

Ansible playbook that provisions a WireGuard VPN server on Debian 12 and generates client `.conf` files locally. All server and peer configuration lives in `peers.yml`.

## Running the Playbook

```bash
# Deploy to real server (uses inventory.ini)
make wg        # also: make xray, make swap
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
./scripts/wg-keygen.sh [N]   # Generate N key pairs in peers.yml YAML format (default: 1)
```

Output is ready to paste into `peers.yml` and is also copied to clipboard if a clipboard tool is available.

## Architecture

```
peers.yml              — Single source of truth: server interface + all client peers
setup-wireguard.yml    — Entry playbook: loads peers.yml, sets wireguard_mode=server, runs the role
inventory.ini          — Production host (wg group)
roles/wireguard/
  defaults/main.yml    — Role defaults (NAT interface, DNS, keepalive, allowed IPs)
  tasks/main.yml       — Install packages → write server.conf → enable IP forwarding → start WG → generate client configs locally
  handlers/main.yml    — Reload WireGuard: `wg syncconf` on wg0.conf changes, no client drops (Address/MTU/PostUp changes need a manual restart)
  templates/
    server.conf.j2     — wg0.conf: Interface + [Peer] for every entry in peers[]
    client.conf.j2     — Per-peer client config (iterated over peers[])
clients/               — Generated client .conf files (one per peer, created locally via delegate_to: localhost)
```

### Data Flow

`peers.yml` defines `interface` (server keys, endpoint, address) and `peers[]` (one entry per device). The role renders `server.conf.j2` onto the remote host and `client.conf.j2` locally for each peer. Client configs reference `interface.public_key` and `interface.endpoint` from `peers.yml`.

### Key Variables

| Variable | Where set | Purpose |
|---|---|---|
| `wireguard_nat_interface` | `defaults/main.yml` | Outbound NIC for iptables MASQUERADE (default `ens3`) |
| `wireguard_allowed_ips` | `defaults/main.yml` | AllowedIPs in client configs (default routes all traffic) |
| `wireguard_dns_servers` | `defaults/main.yml` | DNS in client configs |
| `client_configs_dir` | playbook / defaults | Local output dir for client `.conf` files |

### IP Addressing Convention

Peers are grouped by user with reserved ranges (visible in `peers.yml` comments):
- `10.0.0.2–10` — me
- `10.0.0.11–20` — liza
- `10.0.0.21–30` — andrey_mam
- etc.

When adding a new peer, pick the next free IP in the appropriate range, add the entry to `peers.yml`, and re-run the playbook to update `wg0.conf` and regenerate all client configs.

## peers.yml Contains Real Private Keys

`peers.yml` holds actual WireGuard private keys for all devices. It is tracked in git — treat it as sensitive and do not expose it publicly. Consider migrating to Ansible Vault (`ansible-vault encrypt peers.yml`) for production use.
