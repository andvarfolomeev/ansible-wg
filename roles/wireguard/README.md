# Ansible Role: WireGuard

An Ansible role to set up and configure WireGuard VPN server and client configurations.

## Requirements

- Ansible 2.9 or higher
- Python 3.x
- Supported operating systems:
  - Ubuntu
  - Debian
  - RHEL/CentOS/Rocky Linux 7+

## Role Variables

### Server Configuration

```yaml
wireguard_mode: server  # Set to 'server' for server mode
```

Server interface settings are defined in `peers.yml`:

```yaml
interface:
  address: 10.0.0.1/24       # Server VPN IP address
  listen_port: 51820          # WireGuard port
  private_key: <server_private_key>
  public_key: <server_public_key>
  endpoint: <your_public_ip>:51820
```

### Client Configuration Generation

```yaml
wireguard_generate_client_configs: true  # Set to true to generate client configs
client_configs_dir: "./clients"          # Directory for client config files
```

### Peer Configuration

Peers are defined in `peers.yml`:

```yaml
peers:
  - name: device_name         # Descriptive name (e.g., laptop, phone)
    private_key: <private_key>
    public_key: <public_key>
    allowed_ips: 10.0.0.2/32  # Unique IP for each client
```

## Example Playbook

```yaml
- name: Setup WireGuard VPN
  hosts: vpn_servers
  become: true
  vars_files:
    - ./peers.yml
  vars:
    wireguard_mode: server
    wireguard_generate_client_configs: true
    client_configs_dir: "./clients"
  roles:
    - wireguard
```

## License

MIT

## Author Information

Your Name

## Notes

- Remember to generate unique keys for each device using `wg genkey` and `wg pubkey`
- Keep your private keys secure
- Each client needs a unique IP address within your VPN subnet
