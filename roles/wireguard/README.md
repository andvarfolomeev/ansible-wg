# Role: wireguard

Sets up a WireGuard server `wg0` with NAT on Debian 12 and generates client configs on the control machine.

## Input

The `interface` and `peers` variables, loaded by the playbook from `peers.yml` (see `peers.example.yml`):

```yaml
interface:
  address: 10.0.0.1/24
  listen_port: 51820
  private_key: <server private key>
  public_key: <server public key>
  endpoint: vpn.example.com:51820

peers:
  - name: laptop                # client config file name
    private_key: <private key>
    public_key: <public key>
    allowed_ips: 10.0.0.2/32    # unique per peer
```

The role checks this input before touching the server: all `interface` keys present, peer names, public keys and `allowed_ips` unique, keys 44-character base64 ending in `=`, every `allowed_ips` a single IPv4 `/32`.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `wireguard_nat_interface` | interface of the default route (`ansible_facts['default_ipv4']['interface']`) | Outbound interface for iptables MASQUERADE |
| `client_configs_dir` | `{{ playbook_dir }}/clients` | Local directory for client configs (`0700`, files `0600`) |
| `wireguard_dns_servers` | `8.8.8.8, 8.8.4.4` | DNS in client configs |
| `wireguard_persistent_keepalive` | `25` | Keepalive in client configs |
| `wireguard_allowed_ips` | `0.0.0.0/0, ::/0` | Routes sent through the tunnel by clients |
| `wireguard_mtu` | `1420` | MTU for server and clients, `""` or `null` lets wg-quick auto-detect it |

## Applying changes

Changes to `wg0.conf` are applied with `systemctl reload wg-quick@wg0`, which runs `wg syncconf`: peers and keys update without dropping clients. Address, MTU and PostUp/PostDown changes need a manual `systemctl restart wg-quick@wg0`.

IP forwarding is set in `/etc/sysctl.d/99-wireguard.conf`.

Without systemd (the Docker test container) the role uses `wg-quick up` and `wg syncconf` directly.
