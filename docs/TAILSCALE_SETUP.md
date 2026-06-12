# Tailscale Setup Guide

Complete guide for configuring Tailscale for Packer builds with bastion hosts.

## Overview

This action requires Tailscale for secure connectivity between GitHub Actions runners and OpenStack bastion hosts. This guide covers both OAuth (recommended) and auth key methods.

## Prerequisites

- Tailscale account (free tier works)
- Admin access to Tailscale organization
- GitHub repository with appropriate permissions

## Authentication Methods

### OAuth with Ephemeral Keys (Recommended)

The recommended approach combines OAuth authentication with automatic ephemeral key generation:

**How it works:**

1. GitHub runner authenticates to Tailscale using OAuth credentials
2. Action automatically generates short-lived (1 hour) auth keys via Tailscale API
3. Ephemeral keys are used to connect bastion hosts (reusable for retries)
4. Bastion hosts are automatically removed from Tailscale when destroyed

**Benefits:**

- ✅ Best security with scoped OAuth permissions
- ✅ No static auth keys to manage or rotate
- ✅ Automatic cleanup of ephemeral devices
- ✅ Short-lived credentials (1 hour expiry)
- ✅ Audit logging via OAuth
- ✅ Follows Tailscale security best practices

### OAuth Only (For Runner)

OAuth can be used for the GitHub runner, but requires a separate auth key for bastion hosts:

- ✅ Better security with scoped permissions for runner
- ✅ Automatic token rotation for runner
- ⚠️ Requires manual management of bastion auth keys
- ⚠️ Manual cleanup of bastion devices

### Auth Keys (Legacy)

Auth keys work for both runner and bastion but are deprecated:

- ⚠️ Require manual rotation
- ⚠️ Less granular permissions
- ⚠️ Manual device cleanup required
- ⚠️ Deprecated by Tailscale

---

## Method 1: OAuth Client Setup (Recommended)

### Step 1: Create OAuth Client

1. Go to [Tailscale Admin Console → OAuth Clients](https://login.tailscale.com/admin/settings/oauth)
2. Click **"Generate OAuth client"**
3. Configure settings:
    - **Description:** `GitHub Actions - Packer Builds`
    - **Write Scopes:** Select `auth_keys` and `core`
    - **Tags:** `tag:ci`, `tag:bastion`
4. Click **"Generate client"**
5. **IMPORTANT:** Copy both values immediately:
    - **Client ID:** `kXxXxXxXxXxXCNTRL` → Save as `TAILSCALE_OAUTH_CLIENT_ID`
    - **Client Secret:** `tskey-client-kXxXxXxXxXxXCNTRL-YyYyYyYyYyYyYyYyYyYyYyYyYyYy` → Save as `TAILSCALE_OAUTH_SECRET`

### Step 2: Configure ACLs

Update your Tailscale ACL at <https://login.tailscale.com/admin/acls>

```json
{
    "tagOwners": {
        "tag:ci": ["autogroup:admin", "autogroup:owner", "tag:ci"],
        "tag:bastion": [
            "autogroup:admin",
            "autogroup:owner",
            "tag:ci",
            "tag:bastion"
        ]
    },

    "acls": [
        {
            "action": "accept",
            "src": ["autogroup:admin", "tag:ci", "tag:bastion"],
            "dst": ["*:*"]
        }
    ],

    "grants": [
        {
            "src": ["*"],
            "dst": ["*"],
            "ip": ["*"]
        }
    ],

    "ssh": [
        {
            "action": "accept",
            "src": ["autogroup:member", "tag:ci"],
            "dst": ["tag:bastion"],
            "users": ["root", "ubuntu", "autogroup:nonroot"]
        }
    ],

    "autoApprovers": {
        "routes": {
            "0.0.0.0/0": ["autogroup:admin"],
            "::/0": ["autogroup:admin"]
        },
        "exitNode": ["autogroup:admin"]
    }
}
```

**Key ACL Settings:**

- **tagOwners:** Defines who can create devices with specific tags. Tags can own themselves for OAuth workflows (`tag:ci` owns `tag:ci`, `tag:bastion` owns `tag:bastion`)
- **acls:** Network access rules between tags
- **ssh:** Tailscale SSH permissions (required for bastion access)
- **grants:** IP-level access control (optional, can be more restrictive)

### Step 3: Add GitHub Secrets

Go to **GitHub → Settings → Secrets and variables → Actions**

Add these secrets:

| Secret Name                 | Value                                |
| --------------------------- | ------------------------------------ |
| `TAILSCALE_OAUTH_CLIENT_ID` | `kXxXxXxXxXxXCNTRL` (Client ID)      |
| `TAILSCALE_OAUTH_SECRET`    | `tskey-client-kXxXx...YyYy` (Secret) |

### Step 4: Use in Workflow

**Option 1: OAuth with Ephemeral Keys (Recommended)**

```yaml
- uses: lfreleng-actions/tailscale-openstack-bastion-action@6215d35becaf155eb6c523f339ce7f2647b69812 # main
  with:
      operation: setup
      tailscale_oauth_client_id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
      tailscale_oauth_secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
      tailscale_use_ephemeral_keys: "true" # Default - generates ephemeral keys
      tailscale_tags: "tag:ci,tag:bastion"
      # ... OpenStack parameters
```

The action will:

1. Connect GitHub runner to Tailscale using OAuth
2. Generate a short-lived (1 hour) ephemeral auth key via Tailscale API
3. Use the ephemeral key in bastion cloud-init
4. Bastion auto-removes from Tailscale when destroyed

**Option 2: OAuth for Runner + Static Auth Key for Bastion**

```yaml
- uses: lfreleng-actions/tailscale-openstack-bastion-action@6215d35becaf155eb6c523f339ce7f2647b69812 # main
  with:
      operation: setup
      tailscale_oauth_client_id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
      tailscale_oauth_secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}
      tailscale_auth_key: ${{ secrets.TAILSCALE_AUTH_KEY }} # For bastion
      tailscale_use_ephemeral_keys: "false" # Disable ephemeral key generation
      tailscale_tags: "tag:ci,tag:bastion"
      # ... OpenStack parameters
```

---

## Understanding the Ephemeral Key Flow

When using OAuth with ephemeral keys (`tailscale_use_ephemeral_keys: "true"`):

### 1. GitHub Runner Connection

- Runner authenticates to Tailscale using OAuth client ID/secret
- Runner joins tailnet with tag `tag:ci`
- OAuth tokens are automatically managed

### 2. Auth Key Generation

- Action calls Tailscale API with OAuth credentials
- Generates a unique, short-lived (1 hour) auth key
- Key is configured as:
  - **Persistent Nodes:** Devices survive network disconnects (reliable for bastion use)
  - **Preauthorized:** No manual approval needed
  - **Reusable:** Can retry registration if initial connection fails
  - **Tagged:** Inherits `tag:ci` and `tag:bastion`

### 3. Bastion Provisioning

- Auth key injected into cloud-init script
- Bastion uses key to join tailnet (reusable for retries)
- Key expires after 1 hour or when no longer needed
- Node persists through network disconnects for build reliability

### 4. Automatic Cleanup

- Bastion destroyed → OpenStack VM deleted
- Tailscale node removed during teardown operation
- No manual cleanup required
- Key expires after 1 hour

### Security Benefits

- ✅ **Zero static secrets for bastions:** Keys generated on-demand
- ✅ **Automatic cleanup:** Nodes removed with bastion VM teardown
- ✅ **Short-lived credentials:** 1-hour expiry limits exposure
- ✅ **Reusable for retries:** Handles transient network issues during setup
- ✅ **Audit trail:** All API calls logged via OAuth

---

## Method 2: Auth Key Setup (Legacy)

### Step 1: Generate Auth Key

1. Go to [Tailscale Admin Console → Settings → Keys](https://login.tailscale.com/admin/settings/keys)
2. Click **"Generate auth key"**
3. Configure settings:
    - **Description:** `GitHub Actions - Bastion Hosts`
    - ⚠️ **Ephemeral** - UNCHECK this (persistent nodes needed for bastion reliability)
    - ✅ **Reusable** - Use for multiple workflow runs
    - ✅ **Pre-authorized** - Skip manual approval
    - **Tags:** `tag:bastion`
    - **Expiration:** 90 days (or as needed)
4. Click **"Generate key"**
5. **IMPORTANT:** Copy the key immediately:
    - Starts with `tskey-auth-...`
    - Save as `TAILSCALE_AUTH_KEY`
    - You won't be able to see it again!

### Step 2: Configure ACLs

Use the same ACL configuration as OAuth method above.

### Step 3: Add GitHub Secret

Go to **GitHub → Settings → Secrets and variables → Actions**

Add secret:

| Secret Name          | Value            |
| -------------------- | ---------------- |
| `TAILSCALE_AUTH_KEY` | `tskey-auth-...` |

### Step 4: Use in Workflow

```yaml
- uses: lfit/releng-packer-action@main
  with:
      mode: build
      tailscale_auth_key: ${{ secrets.TAILSCALE_AUTH_KEY }}
      # ... other parameters
```

---

## ACL Configuration Details

### Understanding tagOwners

Tags must be owned to be assigned. The `tagOwners` section defines who can tag devices:

```json
"tagOwners": {
  "tag:ci": ["autogroup:admin", "autogroup:owner", "tag:ci"],
  "tag:bastion": ["autogroup:admin", "autogroup:owner", "tag:ci", "tag:bastion"]
}
```

- **autogroup:admin** - Tailscale admins
- **autogroup:owner** - Organization owners
- **tag:ci** - Devices/clients with `tag:ci` can tag other devices with `tag:bastion`, and can self-own (required for OAuth)
- **tag:bastion** - Can self-own (required for OAuth workflows)

### Understanding ACLs

Network access control between sources and destinations:

```json
"acls": [
  {
    "action": "accept",
    "src": ["autogroup:admin", "tag:ci", "tag:bastion"],
    "dst": ["*:*"]
  }
]
```

- **src:** Who can initiate connections (admin users, CI runners, bastions)
- **dst:** What they can connect to (`*:*` = everything)
- **action:** `accept` allows, `deny` blocks

### Understanding SSH Rules

Tailscale SSH replaces traditional SSH key management:

```json
"ssh": [
  {
    "action": "accept",
    "src": ["autogroup:member", "tag:ci"],
    "dst": ["tag:bastion"],
    "users": ["root", "ubuntu", "autogroup:nonroot"]
  }
]
```

- **src:** Who can SSH (org members, CI runners)
- **dst:** Where they can SSH (bastion hosts)
- **users:** Which users they can SSH as

---

## Verification

### Verify OAuth Client

1. Go to <https://login.tailscale.com/admin/settings/oauth>
2. Find your client: "GitHub Actions - Packer Builds"
3. Check:
    - ✅ Status: Active
    - ✅ Scopes: `auth_keys`
    - ✅ Tags: `tag:ci`, `tag:bastion`

### Verify ACLs

1. Go to <https://login.tailscale.com/admin/acls>
2. Click **"Validate"** button
3. Should show: ✅ "ACL is valid"
4. No errors about missing tags or invalid syntax

### Test Workflow

1. Run workflow manually
2. Check **"Setup Tailscale VPN"** step logs
3. Should see:

    ```
    ✅ Connected to Tailscale network
    ```

4. Verify devices appear at <https://login.tailscale.com/admin/machines>

---

## Troubleshooting

This section documents common Tailscale failures encountered during development and their solutions, organized by authentication method.

### OAuth Client Failures

#### Error: "Status: 403, Message: calling actor does not have enough permissions"

**Symptoms:**

```
timeout 5m sudo -E tailscale up ${TAGS_ARG} --authkey=${TAILSCALE_AUTHKEY}
Status: 403, Message: "calling actor does not have enough permissions to perform this function"
##[error]Process completed with exit code 1.
```

**Root Cause:** OAuth client missing required write scope for `auth_keys`

**Solution:**

1. Delete existing OAuth client
2. Create new OAuth client with:
    - **Write Scopes:** `auth_keys` (not just read)
    - **Tags:** `tag:ci`, `tag:bastion`
3. Update GitHub secret `TAILSCALE_OAUTH_SECRET` with new client secret
4. Verify in OAuth settings that `auth_keys` has write permission

**Prevention:** Always select write scopes, not just read-only scopes

---

#### Error: "requested tags [tag:bastion] are invalid or not permitted"

**Symptoms:**

```
backend error: requested tags [tag:bastion] are invalid or not permitted
2025-10-10 12:02:17,965 - cc_scripts_user.py[WARNING]: Failed to run module scripts_user
```

**Root Cause:** Tags not properly configured in ACL `tagOwners` or OAuth client

**Solution:**

1. Verify ACL configuration includes self-ownership:

    ```json
    "tagOwners": {
      "tag:ci": ["autogroup:admin", "autogroup:owner", "tag:ci"],
      "tag:bastion": ["autogroup:admin", "autogroup:owner", "tag:ci", "tag:bastion"]
    }
    ```

2. Check OAuth client has both tags configured in Tailscale admin console
3. Validate ACL syntax in Tailscale admin console
4. Ensure tags can self-own (`tag:ci` in tagOwners for `tag:ci`)

**Prevention:** Always test ACL changes with "Validate" button before saving

---

#### Error: "An action could not be found at URI" (Setup Failure)

**Symptoms:**

```
##[error]An action could not be found at the URI
'https://api.github.com/repos/tailscale/github-action/tarball/9b0941a...'
```

**Root Cause:** Invalid GitHub Action commit SHA or tag

**Solution:**

1. Verify commit SHA exists in repository:

    ```bash
    git ls-remote https://github.com/tailscale/github-action.git
    ```

2. Use valid commit SHA: `6cae46e2d796f265265cfcf628b72a32b4d7cade` (v3.3.0)
3. Update workflow to use correct reference
4. Consider using tagged release instead of SHA

**Prevention:** Use stable version tags (`v3`) instead of specific commits

---

### Auth Key Failures

#### Error: "tailnet policy does not permit you to SSH to this node"

**Symptoms:**

```
Checking bastion logs:
tailscale: tailnet policy does not permit you to SSH to this node
Connection closed by 100.114.132.117 port 22
```

**Root Cause:** Missing or incorrect SSH rules in Tailscale ACL

**Solution:**

1. Add SSH rules to ACL:

    ```json
    "ssh": [
      {
        "action": "accept",
        "src": ["autogroup:member", "tag:ci"],
        "dst": ["tag:bastion"],
        "users": ["root", "ubuntu", "autogroup:nonroot"]
      }
    ]
    ```

2. Ensure source (`src`) includes `tag:ci` for GitHub runners
3. Ensure destination (`dst`) includes `tag:bastion` for bastion hosts
4. Validate ACL and save changes
5. Wait 30 seconds for ACL propagation

**Prevention:** Include SSH rules when initially configuring ACLs

---

#### Error: "ACL validation failed: only tag:name, group:name, ... are allowed"

**Symptoms:**

```
Error: tagOwners["tag:ci"]: "client:klxjxddgd511cntrl":
only tag:name, group:name, role autogroups, or user@domain are allowed
```

**Root Cause:** Attempting to add OAuth client ID directly to `tagOwners`

**Solution:**

1. Remove client IDs from `tagOwners`
2. Use only valid owner types:
    - `autogroup:admin`
    - `autogroup:owner`
    - `tag:ci` (for self-ownership)
    - User emails (`user@domain.com`)
3. OAuth clients inherit permissions via tags, not direct ownership
4. Validate ACL syntax

**Prevention:** OAuth clients don't appear in `tagOwners` - use tag self-ownership instead

---

### Network & Connectivity Failures

#### Error: Bastion Ready Marker Not Found

**Symptoms:**

```
Waiting for bastion ready marker... (attempt 24/24)
⚠️ Bastion reachable but ready marker not found, proceeding anyway...
```

**Root Cause:**

- Cloud-init failed to complete
- Tailscale failed to start on bastion
- `/tmp/bastion-ready` marker file not created

**Solution:**

1. Check cloud-init logs on bastion:

    ```bash
    openstack console log show bastion-gh-<run-id> | tail -100
    ```

2. Look for Tailscale startup errors
3. Verify bastion instance has outbound internet access
4. Check OpenStack network security groups allow HTTPS (443)
5. Increase `BASTION_WAIT_TIMEOUT` if bastion is slow to boot

**Common Cloud-Init Failures:**

- Network not ready before Tailscale setup
- Missing dependencies (curl, ca-certificates)
- Tailscale package download timeout
- OAuth/auth key credential errors

**Prevention:**

- Use cloud-init with proper dependency ordering
- Add retry logic for network-dependent operations
- Set reasonable timeouts (5+ minutes)

---

#### Error: Bastion Tailscale IP Not Returned

**Symptoms:**

```
=== Bastion Status ===
Hostname: bastion-gh-18406355108
Tailscale IP:
======================
```

**Root Cause:**

- Bastion joined Tailscale but IP not propagated yet
- ACL rules preventing IP assignment
- Tailscale daemon not fully started

**Solution:**

1. Wait 30-60 seconds for IP assignment
2. Check ACL grants allow IP assignment:

    ```json
    "grants": [
      {
        "src": ["*"],
        "dst": ["*"],
        "ip": ["*"]
      }
    ]
    ```

3. Verify bastion in Tailscale admin console shows IP
4. Add retry logic to wait for IP assignment
5. Check `tailscale status` on bastion shows IP address

**Prevention:** Add sleep/retry after bastion joins network

---

### Debug Mode

Enable debug logging to diagnose Tailscale issues:

**In Workflow:**

```yaml
env:
    TS_DEBUG: "1"
```

**Debug Output Shows:**

- Detailed connection attempts
- ACL policy evaluation
- SSH authentication flow
- Network route propagation

**To Enable in Action:**
Add environment variable before Tailscale setup:

```bash
export TS_DEBUG=1
```

---

### Validation Checklist

Before troubleshooting, verify these basics:

#### ✅ OAuth Client Configuration

- [ ] OAuth client exists in Tailscale admin console
- [ ] Client has `auth_keys` **write** scope (not just read)
- [ ] Client configured with tags: `tag:ci`, `tag:bastion`
- [ ] Client status is "Active"
- [ ] GitHub secrets contain correct Client ID and Secret

#### ✅ Auth Key Configuration (if using)

- [ ] Auth key not expired
- [ ] Key has "Ephemeral" enabled
- [ ] Key has "Reusable" enabled
- [ ] Key has "Pre-authorized" enabled
- [ ] Key tagged with `tag:bastion`
- [ ] GitHub secret contains correct auth key

#### ✅ ACL Configuration

- [ ] ACL validated successfully (no errors)
- [ ] `tagOwners` includes self-ownership for tags
- [ ] `acls` allow traffic between `tag:ci` and `tag:bastion`
- [ ] `ssh` rules permit `tag:ci` → `tag:bastion`
- [ ] `grants` allow IP assignment (if using grants)

#### ✅ Network Configuration

- [ ] Bastion instance has outbound internet (HTTPS/443)
- [ ] OpenStack security groups allow required ports
- [ ] Cloud-init has time to complete (5+ min timeout)
- [ ] GitHub runner can reach Tailscale API

#### ✅ GitHub Secrets

- [ ] Secrets exist in repository settings
- [ ] Secret names match workflow inputs exactly
- [ ] Secrets not accidentally wrapped in quotes
- [ ] Secrets updated after regenerating credentials

---

### Common Log Patterns

**Successful OAuth Connection:**

```
✅ Connected to Tailscale network
Tailscale IP: 100.110.229.60
```

**Successful Auth Key Connection:**

```
Success.
100.91.88.61    github-runner-18405791203
```

**Failed OAuth Permissions:**

```
Status: 403, Message: "calling actor does not have enough permissions"
```

**Failed Tag Authorization:**

```
backend error: requested tags [tag:bastion] are invalid or not permitted
```

**Failed SSH Authorization:**

```
tailscale: tailnet policy does not permit you to SSH to this node
Connection closed by X.X.X.X port 22
```

---

### Getting Help

If issues persist after following troubleshooting steps:

1. **Check Workflow Logs:**

    - Download logs from GitHub Actions
    - Look for specific error messages
    - Note timing of failures (setup vs. runtime)

2. **Check Bastion Console Logs:**

    ```bash
    openstack console log show bastion-gh-<run-id> > bastion.log
    ```

3. **Verify Tailscale Admin Console:**

    - Check if devices appear in machine list
    - Review ACL test results
    - Check OAuth client activity logs

4. **Test Locally:**

    - Try connecting with same credentials locally
    - Verify OAuth client works outside GitHub Actions
    - Test SSH rules manually

5. **Open an Issue:**
    - Include workflow logs
    - Include bastion console logs
    - Specify authentication method (OAuth vs auth key)
    - Share ACL configuration (redact sensitive info)

---

## Security Best Practices

### OAuth Secrets

- ✅ Store in GitHub encrypted secrets
- ✅ Never commit to repository
- ✅ Rotate every 90 days
- ✅ Use separate OAuth clients for prod/dev

### Auth Keys

- ✅ Use ephemeral keys (auto-cleanup)
- ✅ Set expiration (90 days max recommended)
- ✅ Regenerate regularly
- ✅ Pre-authorize to avoid manual steps

### ACL Configuration

- ✅ Use principle of least privilege
- ✅ Restrict SSH access to required tags only
- ✅ Regular audit of tag assignments
- ✅ Monitor device connections

---

## Comparison: OAuth vs Auth Keys

| Feature                      | OAuth Client | Auth Key   |
| ---------------------------- | ------------ | ---------- |
| **Setup Complexity**         | Medium       | Simple     |
| **Security**                 | ✅ Better    | ⚠️ Good    |
| **Token Rotation**           | ✅ Automatic | ⚠️ Manual  |
| **Audit Logging**            | ✅ Detailed  | Basic      |
| **Scope Control**            | ✅ Granular  | Fixed      |
| **Recommended For**          | Production   | Testing    |
| **Tailscale Recommendation** | ✅ Preferred | Deprecated |

---

## Additional Resources

- [Tailscale OAuth Clients](https://tailscale.com/kb/1215/oauth-clients)
- [Tailscale ACL Documentation](https://tailscale.com/kb/1018/acls)
- [Tailscale ACL Policy Syntax](https://tailscale.com/kb/1337/policy-syntax)
- [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh)
- [Tailscale Tags](https://tailscale.com/kb/1068/acl-tags)

---

**Need Help?** Open an issue or consult the [main documentation](README.md).
