# Quick Start Guide: OpenStack Bastion with GitHub Actions

Get automated Packer builds running in **15-20 minutes**.

## Prerequisites

- ✅ GitHub repository with Packer files
- ✅ OpenStack account with OpenStack access
- ✅ Tailscale account (free tier works)

---

## Step 1: Get Tailscale Credentials (5 min)

### Create OAuth Key

1. Go to [Tailscale Settings → OAuth Clients](https://login.tailscale.com/admin/settings/oauth)
2. Click **Generate OAuth client**
3. Settings:
    - **Scopes:** `devices:write`
    - **Tags:** `tag:ci`
4. Copy the client secret → This is `TAILSCALE_OAUTH_KEY`

### Create Auth Key

1. Go to [Tailscale Settings → Auth Keys](https://login.tailscale.com/admin/settings/keys)
2. Click **Generate auth key**
3. Settings:
    - ✅ **Ephemeral** (auto-cleanup)
    - ✅ **Reusable** (use for multiple workflows)
    - ✅ **Pre-authorized** (no approval needed)
    - **Tags:** `tag:bastion`
4. Copy the key → This is `TAILSCALE_AUTH_KEY`

---

## Step 2: Get OpenStack Credentials (3 min)

1. Log in to [OpenStack Dashboard](https://console.openstack.net)
2. Navigate to **API Access** or **Project → API Access**
3. Download OpenStack RC file (v3) or copy these values:

```bash
OS_AUTH_URL=https://auth.openstack.net/v3
OS_PROJECT_ID=your-project-id
OS_PROJECT_NAME=your-project-name
OS_USERNAME=your-username
OS_PASSWORD=your-password
OS_REGION_NAME=ca-ymq-1  # or your region
```

**Test credentials locally (optional):**

```bash
pip install python-openstackclient
source openrc.sh  # or export variables
openstack server list
```

---

## Step 3: Configure GitHub Secrets (2 min)

Go to your repo: **Settings → Secrets and variables → Actions → New repository secret**

Add these 8 secrets:

| Secret Name              | Value                | Example                         |
| ------------------------ | -------------------- | ------------------------------- |
| `TAILSCALE_OAUTH_SECRET` | OAuth client secret  | `tskey-client-...`              |
| `TAILSCALE_AUTH_KEY`     | Auth key from Step 1 | `tskey-auth-...`                |
| `OPENSTACK_AUTH_URL`     | OpenStack endpoint   | `https://auth.openstack.net/v3` |
| `OPENSTACK_PROJECT_ID`   | Project ID           | `abc123...`                     |
| `OPENSTACK_PROJECT_NAME` | Project name         | `my-project`                    |
| `OPENSTACK_USERNAME`     | Your username        | `user@example.com`              |
| `OPENSTACK_PASSWORD`     | Your password        | `your-password`                 |
| `OPENSTACK_REGION`       | Region code          | `ca-ymq-1`                      |

---

## Step 4: Setup Repository (5 min)

### Clone This Repository

```bash
git clone https://github.com/your-org/packer-jobs.git
cd packer-jobs
```

### Copy Example Templates

```bash
# Copy examples to packer directory
mkdir -p packer
cp -r examples/templates packer/
cp -r examples/vars packer/
cp -r examples/provision packer/

# Or use your existing packer templates
# Just ensure they support bastion_host variable
```

### Commit and Push

```bash
git add .
git commit -m "Add OpenStack bastion workflow and templates"
git push
```

---

## Step 5: Run Your First Build (2 min)

### Trigger the Workflow

1. Go to GitHub → **Actions** tab
2. Select **Packer Build with OpenStack Tailscale Bastion** workflow
3. Click **Run workflow** → **Run workflow** (green button)

### Expected Timeline

```
00:00 - Checkout & setup tools          (30s)
00:30 - Connect to Tailscale            (15s)
00:45 - Launch bastion on OpenStack      (60s)
01:45 - Bastion joins Tailscale         (30s)
02:15 - Packer init & validate          (30s)
02:45 - Packer build starts             (5-15 min)
17:45 - Build complete, cleanup         (30s)
18:15 - Workflow finished ✅
```

### Monitor Progress

- **GitHub Actions UI:** See each step's logs
- **Tailscale Admin:** Watch bastion appear in devices list
- **OpenStack Dashboard:** See instance being created/deleted

---

## Verification Checklist

After your first successful run:

- [ ] Workflow completed without errors
- [ ] Bastion appeared in Tailscale admin console
- [ ] OpenStack instance was created and deleted
- [ ] Packer build produced expected image
- [ ] No lingering resources in OpenStack
- [ ] Tailscale device auto-removed (ephemeral enabled)

---

## Common First-Run Issues

### ❌ "Authentication failed" (OpenStack)

**Fix:** Double-check OpenStack credentials in GitHub secrets

```bash
# Test locally first
openstack server list
```

### ❌ "Tailscale connection timeout"

**Fix:** Check auth key settings - must be reusable and pre-authorized

- Regenerate key with correct settings
- Update `TAILSCALE_AUTH_KEY` secret

### ❌ "Bastion never appears in Tailscale"

**Fix:** Cloud-init might have failed

- Check OpenStack console logs for the instance
- Try different base image (Ubuntu 22.04 recommended)
- Increase `BASTION_WAIT_TIMEOUT` in workflow

### ❌ "Packer validation failed"

**Fix:** Ensure templates support bastion variables

```bash
# Test locally
cd packer
packer init templates/
packer validate -var-file=vars/ubuntu-22.04.pkrvars.hcl templates/builder.pkr.hcl
```

---

## Next Steps

### Test Templates Locally

```bash
./test-templates.sh
```

### Customize Workflow

Edit `.github/workflows/packer-openstack-bastion-build.yaml`:

```yaml
env:
    OPENSTACK_FLAVOR: "v3-starter-1" # Smaller instance
    BASTION_WAIT_TIMEOUT: 600 # Longer timeout
```

### Trigger on Push

```yaml
on:
    push:
        branches: [main]
        paths:
            - "packer/**"
```

### Schedule Builds

```yaml
on:
    schedule:
        - cron: "0 2 * * 1" # Weekly Monday 2 AM
```

### Add More Templates

```bash
cp examples/templates/builder.pkr.hcl packer/templates/docker.pkr.hcl
# Customize docker.pkr.hcl for your needs
```

---

## Cost Estimate

### OpenStack Costs (approx)

- **Bastion instance:** v3-standard-2 @ ~$0.08/hour
- **Average build time:** 15 minutes
- **Cost per build:** ~$0.02
- **Monthly (daily builds):** ~$0.60/month

### Tailscale Costs

- **Free tier:** 100 devices, unlimited users
- **Ephemeral devices:** FREE (don't count toward limit)

**Total estimated cost:** < $1/month for daily builds 💰

---

## Support & Resources

### Documentation

- 📖 **Main README:** `README.md`
- 📖 **Troubleshooting:** `docs/TROUBLESHOOTING.md`
- 📖 **Examples:** `examples/README.md`

### Troubleshooting

Enable debug mode in workflow dispatch:

- Set `debug_mode: true`

Check logs:

- GitHub Actions → Workflow run → Download artifacts
- OpenStack console logs
- Tailscale admin panel

### Community

- **GitHub Discussions:** Ask questions in your repo
- **Tailscale Community:** <https://tailscale.com/kb/>
- **OpenStack Support:** <https://openstack.com/support/>

---

## Quick Reference Commands

### Test OpenStack Connection

```bash
openstack server list
openstack image list
openstack flavor list
```

### Validate Packer Templates

```bash
cd packer
packer init templates/
packer validate -var-file=vars/ubuntu-22.04.pkrvars.hcl templates/builder.pkr.hcl
```

### Manual Bastion Test

```bash
# Create test cloud-init
cat > test-cloud-init.yaml <<EOF
#cloud-config
runcmd:
  - curl -fsSL https://tailscale.com/install.sh | sh
  - tailscale up --authkey=YOUR_AUTH_KEY --hostname=test-bastion --ssh
EOF

# Launch test bastion
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

---

## Success! 🎉

You now have:

✅ Automated Packer builds from GitHub Actions
✅ Secure VPN connectivity via Tailscale
✅ Ephemeral bastion hosts (auto-cleanup)
✅ No manual SSH configuration needed
✅ Scalable CI/CD pipeline

**Time to first build:** ~15-20 minutes
**Time for subsequent builds:** Fully automated!

---

**Need help?** See `docs/TROUBLESHOOTING.md` or open an issue.
