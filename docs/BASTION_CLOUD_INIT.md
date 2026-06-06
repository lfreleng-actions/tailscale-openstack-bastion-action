# Bastion Cloud-Init Configuration

This document explains the cloud-init configuration used for OpenStack bastion hosts.

## Overview

The bastion cloud-init script (`templates/bastion-cloud-init.yaml`) is used during OpenStack instance creation to automatically configure the bastion host for Tailscale connectivity and Packer builds.

## Configuration Sections

### System Configuration

```yaml
hostname: ${BASTION_HOSTNAME}
manage_etc_hosts: true
package_update: true
package_upgrade: true
timezone: UTC
```

- Sets hostname to unique bastion name (e.g., `bastion-gh-12345`)
- Updates package lists and upgrades system packages
- Configures UTC timezone

### Package Installation

Essential packages installed:

- **Utilities:** curl, wget, jq, unzip, git
- **Network tools:** netcat, net-tools, iputils-ping, traceroute
- **Security:** apt-transport-https, ca-certificates, gnupg
- **Build tools:** build-essential, python3, python3-pip

### System Files

#### Sysctl Configuration (`/etc/sysctl.d/99-tailscale.conf`)

Enables IP forwarding for network routing:

```
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.netfilter.nf_conntrack_max = 131072
```

Required for Tailscale to function as a bastion/jump host.

#### Bastion Initialization Script (`/usr/local/bin/bastion-init.sh`)

Main initialization script that:

1. Waits for network connectivity
2. Installs Tailscale
3. Authenticates with Tailscale network
4. Creates ready marker at `/tmp/bastion-ready`
5. Logs all operations to `/var/log/bastion-init.log`

#### MOTD Banner (`/etc/motd`)

Displays informational banner when SSH users log in.

### User Configuration

```yaml
users:
    - name: ubuntu
      sudo: ALL=(ALL) NOPASSWD:ALL
      shell: /bin/bash
      groups: sudo
      lock_passwd: true
```

- Creates/configures ubuntu user with passwordless sudo
- Locks password (SSH key auth only)

### SSH Configuration

```yaml
ssh_pwauth: false
disable_root: false
```

- Disables password authentication (key-based only)
- Allows root login (for Tailscale SSH)

### Run Commands

```yaml
runcmd:
    - sysctl -p /etc/sysctl.d/99-tailscale.conf
    - /usr/local/bin/bastion-init.sh
```

1. Applies sysctl settings
2. Runs bastion initialization script

## Environment Variables

The cloud-init script expects these variables to be substituted:

| Variable                | Description                 | Example            |
| ----------------------- | --------------------------- | ------------------ |
| `${BASTION_HOSTNAME}`   | Unique hostname for bastion | `bastion-gh-12345` |
| `${TAILSCALE_AUTH_KEY}` | Tailscale auth key          | `tskey-auth-...`   |

These are substituted by the workflow before instance creation.

## Initialization Process

### Timeline

```
0:00 - Instance boots
0:10 - Cloud-init starts
0:15 - Package updates begin
0:45 - Packages installed
0:50 - Sysctl applied
0:55 - Bastion init script starts
1:00 - Network check passes
1:05 - Tailscale installation starts
1:25 - Tailscale installed
1:30 - Tailscale authentication
1:45 - Tailscale connected
1:50 - Ready marker created
1:55 - Initialization complete
```

Total time: ~2 minutes

### Logs

All initialization steps are logged to `/var/log/bastion-init.log`:

```bash
# View logs via SSH
ssh root@<bastion-ip> cat /var/log/bastion-init.log

# Or via workflow
openstack console log show bastion-gh-12345
```

### Ready Marker

The workflow checks for `/tmp/bastion-ready` file to confirm initialization:

```bash
# Check if bastion is ready
ssh root@<bastion-ip> "test -f /tmp/bastion-ready && echo 'Ready' || echo 'Not ready'"
```

## Tailscale Configuration

### Authentication

```bash
tailscale up \
  --authkey="${TAILSCALE_AUTH_KEY}" \
  --hostname="${BASTION_HOSTNAME}" \
  --advertise-tags=tag:bastion \
  --ssh \
  --accept-routes \
  --accept-dns=false
```

Options:

- `--authkey`: Pre-authorized reusable key
- `--hostname`: Unique identifier
- `--advertise-tags`: Tag as bastion for ACLs
- `--ssh`: Enable Tailscale SSH (no keys needed)
- `--accept-routes`: Accept subnet routes
- `--accept-dns=false`: Don't override DNS

### Network Features

With IP forwarding enabled, the bastion can:

- Route traffic to OpenStack internal network
- Act as SSH jump host for Packer builds
- Forward connections to build target instances

## Troubleshooting

### Check Cloud-Init Status

```bash
# Via SSH
ssh root@<bastion-ip> cloud-init status --wait
ssh root@<bastion-ip> cloud-init status --long

# View cloud-init logs
ssh root@<bastion-ip> cat /var/log/cloud-init-output.log
```

### Check Bastion Init Log

```bash
ssh root@<bastion-ip> cat /var/log/bastion-init.log
```

### Check Tailscale Status

```bash
ssh root@<bastion-ip> tailscale status
ssh root@<bastion-ip> tailscale ip -4
```

### Common Issues

#### Network Not Ready

**Symptom:** Script waiting indefinitely for network

**Solution:** Check OpenStack network configuration

```bash
openstack server show bastion-gh-12345 | grep network
```

#### Tailscale Install Failed

**Symptom:** Tailscale not found after init

**Solution:** Check installation logs

```bash
ssh root@<bastion-ip> "journalctl -u tailscaled"
```

#### Auth Key Invalid

**Symptom:** Tailscale fails to authenticate

**Solution:**

- Verify auth key is not expired
- Check key is reusable and pre-authorized
- Regenerate key in Tailscale admin

## Customization

### Adding Additional Packages

Edit `packages` section:

```yaml
packages:
    - curl
    - your-package-here
```

### Adding Additional Configuration

Add to `write_files` section:

```yaml
write_files:
    - path: /etc/your-config
      content: |
          your configuration here
      permissions: "0644"
```

### Adding Post-Install Commands

Add to `runcmd` section:

```yaml
runcmd:
    - your-command-here
    - another-command
```

## Integration with Workflow

### Workflow Usage

```yaml
- name: Create cloud-init script
  run: |
      export BASTION_HOSTNAME="bastion-gh-${{ github.run_id }}"
      export TAILSCALE_AUTH_KEY="${{ secrets.TAILSCALE_AUTH_KEY }}"
      envsubst < templates/bastion-cloud-init.yaml > cloud-init.yaml

- name: Launch bastion
  run: |
      openstack server create \
        --user-data cloud-init.yaml \
        --flavor v3-standard-2 \
        --image "Ubuntu 22.04" \
        bastion-gh-${{ github.run_id }}
```

### Fallback Configuration

If `templates/bastion-cloud-init.yaml` is not present, the workflow uses an inline cloud-init configuration with essential features.

## Security Considerations

### SSH Access

- Password authentication disabled
- Root login allowed (via Tailscale SSH only)
- No SSH keys stored in cloud-init
- Tailscale handles authentication

### Network Security

- Bastion only accessible via Tailscale VPN
- No public IP required
- IP forwarding restricted to Tailscale network
- Connection tracking limits prevent abuse

### Secrets Management

- Tailscale auth key passed via environment variable
- Not logged or stored on disk
- Ephemeral instance (auto-deleted)

## Testing

### Local Testing

```bash
# Test cloud-init syntax
cloud-init schema --config-file templates/bastion-cloud-init.yaml

# Validate YAML
python3 -c "import yaml; yaml.safe_load(open('templates/bastion-cloud-init.yaml'))"
```

### Manual Bastion Test

```bash
# Set variables
export BASTION_HOSTNAME="test-bastion"
export TAILSCALE_AUTH_KEY="your-auth-key"

# Generate cloud-init
envsubst < templates/bastion-cloud-init.yaml > test-cloud-init.yaml

# Launch test instance
openstack server create \
  --flavor v3-standard-2 \
  --image "Ubuntu 22.04" \
  --network default \
  --user-data test-cloud-init.yaml \
  test-bastion

# Wait and check
sleep 120
tailscale status | grep test-bastion

# Cleanup
openstack server delete test-bastion
```

## References

- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
- [Tailscale Installation](https://tailscale.com/kb/1031/install-linux/)
- [OpenStack User Data](https://docs.openstack.org/nova/latest/user/user-data.html)
- [Bastion Host Best Practices](https://tailscale.com/kb/1080/bastion/)

## Change Log

### Version 1.0 (Current)

- Initial cloud-init configuration
- Tailscale integration
- Network forwarding setup
- Ready marker implementation
- Comprehensive logging
