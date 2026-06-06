# Troubleshooting Guide

Common issues and solutions for the OpenStack Tailscale Bastion workflow.

## Table of Contents

- [OpenStack Issues](#openstack-issues)
- [Tailscale Issues](#tailscale-issues)
- [Bastion Issues](#bastion-issues)
- [Packer Issues](#packer-issues)
- [Network Issues](#network-issues)
- [Debug Techniques](#debug-techniques)

---

## OpenStack Issues

### ❌ Authentication Failed

**Symptoms:**

```
Error: Authentication failed
Unable to authenticate to OpenStack
```

**Solutions:**

1. Verify credentials in GitHub secrets:

    ```bash
    # Test locally first
    export OS_AUTH_URL="https://auth.openstack.net/v3"
    export OS_PROJECT_NAME="your-project"
    export OS_USERNAME="your-username"
    export OS_PASSWORD="your-password"
    export OS_REGION_NAME="ca-ymq-1"

    openstack server list
    ```

2. Check secret names match exactly:

    - `OPENSTACK_AUTH_URL`
    - `OPENSTACK_PROJECT_NAME`
    - `OPENSTACK_USERNAME`
    - `OPENSTACK_PASSWORD`
    - `OPENSTACK_REGION`

3. Verify OpenStack account is active and has quota

### ❌ Insufficient Quota

**Symptoms:**

```
Error: Quota exceeded for instances
Error: Quota exceeded for cores
```

**Solutions:**

1. Check current usage:

    ```bash
    openstack quota show
    openstack server list
    ```

2. Delete unused instances:

    ```bash
    openstack server list
    openstack server delete <instance-name>
    ```

3. Request quota increase from OpenStack support

4. Use smaller instance flavor:

    ```yaml
    bastion_flavor: "v3-starter-1" # Smaller/cheaper
    ```

### ❌ Image Not Found

**Symptoms:**

```
Error: Image 'Ubuntu 22.04' not found
```

**Solutions:**

1. List available images:

    ```bash
    openstack image list
    ```

2. Update workflow with exact image name:

    ```yaml
    bastion_image: "Ubuntu-22.04-x86_64" # Exact name from image list
    ```

3. Common OpenStack image names:
    - `Ubuntu 22.04`
    - `Ubuntu-22.04-x86_64`
    - `ubuntu-22.04`

---

## Tailscale Issues

### ❌ Tailscale Connection Timeout

**Symptoms:**

```
Error: Timeout waiting for bastion to join Tailscale
Bastion never appears in tailscale status
```

**Solutions:**

1. **Check Auth Key Settings:**

    - Go to Tailscale admin → Auth Keys
    - Verify key has these settings:
        - ✅ Reusable
        - ✅ Pre-authorized
        - ✅ Ephemeral (recommended)
    - Tags: `tag:bastion`

2. **Regenerate Auth Key:**

    ```bash
    # In Tailscale admin console
    1. Revoke old key
    2. Generate new key with correct settings
    3. Update GitHub secret TAILSCALE_AUTH_KEY
    ```

3. **Check ACLs:**

    - Ensure `tag:ci` and `tag:bastion` are allowed to communicate
    - Review Tailscale ACL policy

4. **Increase Timeout:**

    ```yaml
    env:
        BASTION_WAIT_TIMEOUT: 600 # 10 minutes
    ```

### ❌ OAuth Key Invalid

**Symptoms:**

```
Error: Invalid OAuth client key
Tailscale authentication failed
```

**Solutions:**

1. Verify OAuth key scope includes `devices:write`

2. Regenerate OAuth client:

    - Go to Tailscale Settings → OAuth Clients
    - Generate new client with `devices:write` scope
    - Update `TAILSCALE_OAUTH_SECRET` secret

3. Check OAuth client is not expired or revoked

### ❌ Device Name Conflict

**Symptoms:**

```
Error: Device name already exists
Hostname conflict in Tailscale network
```

**Solutions:**

1. Workflow uses unique names by default: `bastion-gh-${{ github.run_id }}`

2. Clean up old devices in Tailscale admin console

3. Enable ephemeral keys for auto-cleanup

---

## Bastion Issues

### ❌ Bastion Instance Never Starts

**Symptoms:**

```
Instance stuck in BUILD state
Instance shows ERROR status
```

**Solutions:**

1. **Check Instance Status:**

    ```bash
    openstack server show bastion-gh-XXXXX
    ```

2. **View Console Log:**

    ```bash
    openstack console log show bastion-gh-XXXXX --lines 100
    ```

3. **Common Causes:**

    - Insufficient quota
    - Invalid flavor
    - Network issues
    - Image corrupted

4. **Try Different Base Image:**

    ```yaml
    bastion_image: "Ubuntu 24.04" # Try newer version
    ```

### ❌ Cloud-Init Failed

**Symptoms:**

```
Bastion instance running but never joins Tailscale
SSH connection refused
```

**Solutions:**

1. **Check Console Output:**

    ```bash
    openstack console log show bastion-gh-XXXXX --lines 200
    ```

2. **Access via VNC Console:**

    ```bash
    openstack console url show bastion-gh-XXXXX
    # Open URL in browser
    ```

3. **Common Cloud-Init Errors:**

    - Network not available during boot
    - Tailscale install script failed
    - Auth key expired or invalid

4. **Manual Verification:**
    - Login via VNC console
    - Check `/var/log/cloud-init-output.log`
    - Check `/var/log/cloud-init.log`
    - Run `cloud-init status --wait`

### ❌ SSH Connection Failed

**Symptoms:**

```
SSH connection timeout
Permission denied (publickey)
```

**Solutions:**

1. **Verify Bastion is in Tailscale:**

    ```bash
    sudo tailscale status | grep bastion
    ```

2. **Test Connectivity:**

    ```bash
    ping <bastion-tailscale-ip>
    ```

3. **Check SSH Service:**

    - Access via VNC console
    - Run `systemctl status sshd`
    - Run `systemctl status ssh`

4. **Tailscale SSH:**
    - Workflow uses `--ssh` flag in cloud-init
    - SSH should work without keys via Tailscale

---

## Packer Issues

### ❌ Packer Validation Failed

**Symptoms:**

```
Error: Invalid template syntax
Error: Missing required variable
```

**Solutions:**

1. **Test Template Locally:**

    ```bash
    cd packer
    packer init templates/
    packer fmt templates/
    packer validate -var-file=vars/ubuntu-22.04.pkrvars.hcl templates/builder.pkr.hcl
    ```

2. **Check Variable Files:**

    - Ensure all required variables are defined
    - Check for syntax errors in `.pkrvars.hcl` files

3. **Verify Bastion Variables:**

    ```hcl
    variable "bastion_host" {
      type    = string
      default = ""
    }

    variable "bastion_user" {
      type    = string
      default = "root"
    }
    ```

### ❌ Packer Build Failed

**Symptoms:**

```
Error: Timeout waiting for SSH
Error: Connection refused
Build failed during provisioning
```

**Solutions:**

1. **Enable Debug Logging:**

    - Set workflow input `debug_mode: true`
    - Or add to workflow:

        ```yaml
        env:
            PACKER_LOG: 1
        ```

2. **Check Bastion Connectivity:**

    - Verify bastion can reach build instance
    - Check network security groups
    - Verify SSH port is open

3. **Increase Timeouts:**

    ```hcl
    ssh_timeout = "20m"
    ssh_handshake_attempts = 20
    ```

4. **Check Build Instance:**

    ```bash
    openstack server list  # Find build instance
    openstack console log show <build-instance>
    ```

### ❌ Plugin Installation Failed

**Symptoms:**

```
Error: Failed to install plugin
Plugin not found
```

**Solutions:**

1. **Initialize Plugins:**

    ```bash
    packer init templates/
    ```

2. **Check Required Plugins:**

    ```hcl
    packer {
      required_plugins {
        openstack = {
          version = ">= 1.0.0"
          source  = "github.com/hashicorp/openstack"
        }
      }
    }
    ```

3. **Cache Plugins (in workflow):**

    ```yaml
    - name: Cache Packer plugins
      uses: actions/cache@v3
      with:
          path: ~/.packer.d/plugins
          key: packer-plugins-${{ runner.os }}
    ```

---

## Network Issues

### ❌ Cannot Reach OpenStack API

**Symptoms:**

```
Error: Connection timeout to auth.openstack.net
Error: Unable to reach OpenStack endpoint
```

**Solutions:**

1. **Verify Auth URL:**

    ```bash
    curl -I https://auth.openstack.net/v3
    ```

2. **Check GitHub Runner Network:**

    - GitHub runners should have internet access
    - No additional firewall rules needed

3. **Test from Runner:**

    ```yaml
    - name: Test connectivity
      run: |
          curl -v https://auth.openstack.net/v3
          ping -c 3 auth.openstack.net
    ```

### ❌ Bastion Cannot Reach Build Instance

**Symptoms:**

```
Packer SSH timeout
Bastion cannot connect to target
```

**Solutions:**

1. **Check Network Configuration:**

    - Verify both instances on same network
    - Check security group rules
    - Verify network exists:

        ```bash
        openstack network list
        ```

2. **Update Network in Workflow:**

    ```yaml
    env:
        OPENSTACK_NETWORK: "your-network-name"
    ```

3. **Check Security Groups:**

    ```bash
    openstack security group list
    openstack security group rule list default
    ```

4. **Allow SSH Between Instances:**

    ```bash
    openstack security group rule create \
      --protocol tcp \
      --dst-port 22 \
      --remote-ip 0.0.0.0/0 \
      default
    ```

---

## Debug Techniques

### Enable Verbose Logging

**In Workflow:**

```yaml
env:
    PACKER_LOG: 1
    ACTIONS_STEP_DEBUG: true
```

**In Workflow Dispatch:**

- Set `debug_mode: true`

### View Bastion Logs

**Access Cloud-Init Logs:**

```bash
# Via SSH (if accessible)
ssh root@<bastion-tailscale-ip>
cat /var/log/cloud-init-output.log
cloud-init status --long
```

**Via Console:**

```bash
openstack console log show bastion-gh-XXXXX --lines 200
```

### Manual Bastion Testing

**Launch Test Bastion:**

```bash
# Create cloud-init file
cat > test-cloud-init.yaml <<EOF
#cloud-config
runcmd:
  - curl -fsSL https://tailscale.com/install.sh | sh
  - tailscale up --authkey=YOUR_AUTH_KEY --hostname=test-bastion --ssh
EOF

# Launch instance
openstack server create \
  --flavor v3-standard-2 \
  --image "Ubuntu 22.04" \
  --network default \
  --user-data test-cloud-init.yaml \
  test-bastion

# Wait and check
sleep 60
tailscale status | grep test-bastion

# Cleanup
openstack server delete test-bastion
```

### Check Tailscale Status

**On GitHub Runner:**

```bash
sudo tailscale status
sudo tailscale ping <bastion-hostname>
sudo tailscale netcheck
```

**View Logs:**

```bash
sudo journalctl -u tailscaled
```

### Download Workflow Artifacts

1. Go to GitHub Actions → Workflow run
2. Scroll to "Artifacts" section
3. Download:
    - `packer-logs-XXXXX`
    - `bastion-logs-XXXXX`

### Live Debugging

**Add Debugging Step:**

```yaml
- name: Debug - List resources
  if: failure()
  run: |
      echo "=== OpenStack Resources ==="
      openstack server list
      openstack network list

      echo "=== Tailscale Status ==="
      sudo tailscale status

      echo "=== Environment ==="
      env | grep -E '(OS_|BASTION_)' | sort
```

### Common Debug Commands

```bash
# Check OpenStack connectivity
openstack server list
openstack image list
openstack flavor list
openstack network list

# Check Tailscale
sudo tailscale status
sudo tailscale ping <hostname>

# Check bastion instance
openstack server show bastion-gh-XXXXX
openstack console log show bastion-gh-XXXXX

# Test SSH
ssh -v root@<bastion-tailscale-ip>

# Packer debug
packer validate -var-file=... template.pkr.hcl
PACKER_LOG=1 packer build -var-file=... template.pkr.hcl
```

---

## Getting Help

### Check Documentation

- Main README: `README.md`
- Quick Start: `docs/QUICK_START.md`
- This guide: `docs/TROUBLESHOOTING.md`

### View Logs

- GitHub Actions logs
- Packer logs artifact
- Bastion logs artifact
- OpenStack console logs

### Community Support

- GitHub Discussions
- Tailscale Community Forum
- OpenStack Support Portal
- Packer Community Forum

### Reporting Issues

When reporting issues, include:

1. **Workflow Run URL**
2. **Error Messages** (full output)
3. **Environment:**
    - Packer version
    - OpenStack image/flavor
    - GitHub runner OS
4. **Logs:**
    - Workflow logs
    - Packer logs
    - Bastion console log
5. **Configuration:**
    - Workflow inputs used
    - Template/vars files
6. **Steps to Reproduce**

---

## Best Practices

### 1. Test Locally First

```bash
# Test OpenStack connection
openstack server list

# Test Packer templates
packer init templates/
packer validate -var-file=vars/ubuntu-22.04.pkrvars.hcl templates/builder.pkr.hcl
```

### 2. Start Simple

- Use default workflow settings first
- Build one template at a time
- Use proven base images (Ubuntu 22.04)

### 3. Use Ephemeral Keys

- Always use ephemeral Tailscale auth keys
- Enable auto-cleanup features
- Set reasonable expiration times

### 4. Monitor Costs

- Check OpenStack billing regularly
- Delete unused instances
- Use appropriate instance flavors

### 5. Keep Secrets Secure

- Rotate credentials regularly
- Use minimal required permissions
- Never commit secrets to git

### 6. Enable Cleanup

- Workflow has automatic cleanup
- Verify cleanup completed
- Manual cleanup if workflow fails:

```bash
# List bastion instances
openstack server list | grep bastion-gh

# Delete if needed
openstack server delete bastion-gh-XXXXX
```

---

## Quick Reference

### Essential Commands

```bash
# OpenStack
openstack server list
openstack server show <name>
openstack server delete <name>
openstack console log show <name>

# Tailscale
sudo tailscale status
sudo tailscale ping <hostname>

# Packer
packer init <template>
packer validate <template>
packer build <template>

# Debugging
export PACKER_LOG=1
export OS_DEBUG=1
```

### Important Files

- Workflow: `.github/workflows/packer-openstack-bastion-build.yaml`
- Pre-commit: `.pre-commit-config.yaml`
- Yamllint: `.yamllint.conf`
- Documentation: `docs/`

### Key Environment Variables

```bash
# OpenStack
OS_AUTH_URL
OS_PROJECT_NAME
OS_USERNAME
OS_PASSWORD
OS_REGION_NAME

# Workflow
BASTION_NAME
BASTION_IP
PACKER_VERSION
OS_CLOUD
```
