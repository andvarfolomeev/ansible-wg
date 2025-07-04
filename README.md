# Ansible WireGuard Configuration

A simple Ansible playbook to set up a WireGuard VPN server and manage client configurations.

## Overview

This project allows you to:
- Configure a WireGuard VPN server
- Manage client peers in a single configuration file
- Generate client configurations automatically

## Requirements

- Ansible 2.9+
- Target server with Debian 12
- Python 3.x

## Quick Start

1. Clone this repository
2. Edit `peers.yml` to configure your server and clients
3. Run the playbook:

```bash
ansible-playbook -i inventory.ini setup-wireguard.yml
```

## Configuration

### Server Configuration

Edit `peers.yml` to configure your WireGuard server:

```yaml
interface:
  address: 10.0.0.1/24       # Server VPN IP address
  listen_port: 51820          # WireGuard port
  private_key: <server_private_key>
  public_key: <server_public_key>
  endpoint: <your_public_ip>:51820
```

### Client Peers Configuration

Add client peers to the `peers.yml` file:

```yaml
peers:
  - name: device_name         # Descriptive name (e.g., laptop, phone)
    private_key: <private_key>
    public_key: <public_key>
    allowed_ips: 10.0.0.2/32  # Unique IP for each client
```

Each peer needs:
- A unique name (used for configuration file names)
- WireGuard keys (generate with `wg genkey` and `wg pubkey`)
- A unique IP address within your VPN subnet

## Testing with Docker

A Dockerfile and example inventory are included for testing:

1. Build the test container:
```bash
docker build -t wg-test .
```

2. Run the container:
```bash
docker run -d -p 2222:22 --privileged --name wg-test wg-test
```

3. Run the playbook with the Docker inventory:
```bash
ansible-playbook -i inventory_docker_example.ini setup-wireguard.yml
```

## Security Notes

- Never share your private keys
- Generate new keys for each device
- Keep your `peers.yml` file secure
- Consider using Ansible Vault for production deployments

## Generated Client Configurations

Client configuration files will be generated in the `./clients` directory.
These files can be directly imported into WireGuard clients on various platforms.
