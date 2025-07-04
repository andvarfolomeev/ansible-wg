# WireGuard Role

A simplified Ansible role for deploying and managing WireGuard VPN servers and clients.

## Overview

This role handles the installation, configuration, and management of WireGuard VPN on both servers and clients. It uses a single unified approach instead of separate server and client roles, making it easier to maintain and deploy.

## Features

- Single role for both server and client setups
- Automatic key generation if not provided
- NAT configuration for server mode
- Client configuration generation
- Configurable network settings

## Requirements

- Debian/Ubuntu-based system (apt package manager)
- Ansible 2.9+
- Root privileges (become: yes)

## Role Variables

All variables have sensible defaults and can be overridden as needed.

### Mode Selection

```yaml
# Mode can be 'server' or 'client'
wireguard_mode: server
```

### Network Configuration

```yaml
# Interface configuration
wireguard_address: "10.0.0.1/24"  # IP address with CIDR notation
wireguard_listen_port: 51820      # Port for WireGuard to listen on
wireguard_nat_interface: eth0     # Network interface for NAT (server mode)
```

### Key Management

Keys are automatically generated if not provided:

```yaml
# Optional - provide your own keys
# wireguard_private_key: "your-private-key"
# wireguard_public_key: "your-public-key"
```

### Client Configuration

```yaml
# Client configuration generation
wireguard_generate_client_configs: false   # Set to true to generate client configs
client_configs_dir: "./clients"            # Directory to store client configs

# DNS servers for clients
wireguard_dns_servers: "8.8.8.8, 8.8.4.4"

# Server endpoint for clients to connect to
wireguard_endpoint: ""

# Client persistent keepalive in seconds
wireguard_persistent_keepalive: 25

# Default allowed IPs (0.0.0.0/0 routes all traffic through VPN)
wireguard_allowed_ips: "0.0.0.0/0, ::/0"
```

## Example Playbooks

### Server Setup

```yaml
---
- name: Setup WireGuard VPN Server
  hosts: vpn_servers
  become: true
  vars_files:
    - vars/wireguard_peers.yml
  vars:
    wireguard_mode: server
  roles:
    - wireguard_refactored
```

### Client Setup

```yaml
---
- name: Setup WireGuard VPN Client
  hosts: vpn_clients
  become: true
  vars:
    wireguard_mode: client
    wireguard_address: "10.0.0.2/24"
    wireguard_endpoint: "vpn.example.com:51820"
    wireguard_server_public_key: "server-public-key-here"
  roles:
    - wireguard_refactored
```

### Generate Client Configs

```yaml
---
- name: Generate WireGuard Client Configs
  hosts: localhost
  connection: local
  gather_facts: false
  vars_files:
    - vars/wireguard_peers.yml
  vars:
    wireguard_mode: server
    wireguard_generate_client_configs: true
    client_configs_dir: "./clients"
  roles:
    - wireguard_refactored
```

## Peer Configuration

For server mode, peers should be defined in a variables file (e.g., `vars/wireguard_peers.yml`):

```yaml
interface:
  address: 10.0.0.1/24
  listen_port: 51820
  private_key: "server-private-key"
  public_key: "server-public-key"
  endpoint: "server-public-ip:51820"

peers:
  - name: client1
    private_key: "client1-private-key"
    public_key: "client1-public-key"
    allowed_ips: 10.0.0.2/32
  - name: client2
    private_key: "client2-private-key"
    public_key: "client2-public-key"
    allowed_ips: 10.0.0.3/32
```

## License

MIT