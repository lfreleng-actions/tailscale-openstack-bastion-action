# Gerrit Integration Guide

This guide explains how to integrate the Packer OpenStack Bastion Action with Gerrit-based workflows.

## Overview

The action supports two modes designed for Gerrit-based development workflows:

1. **Validate Mode** - Triggered on Gerrit verify (patchset-created events)

    - Validates Packer syntax and configuration
    - Runs quickly without creating infrastructure
    - Used in pre-merge validation

2. **Build Mode** - Triggered on Gerrit merge or scheduled builds
    - Creates actual images using bastion host
    - Publishes images to cloud provider
    - Used post-merge or for periodic rebuilds

## Prerequisites

### Repository Setup

Your repository should follow this structure:

```
releng/builder/  (or similar)
├── .github/
│   └── workflows/
│       ├── gerrit-verify.yaml    # Validation workflow
│       └── gerrit-merge.yaml     # Build workflow (optional)
├── packer/
│   ├── common-packer/            # Git submodule
│   │   └── vars/
│   │       ├── ubuntu-22.04.pkrvars.hcl
│   │       ├── ubuntu-24.04.pkrvars.hcl
│   │       └── ...
│   └── templates/
│       ├── builder.pkr.hcl
│       ├── docker.pkr.hcl
│       └── ...
└── jjb/                          # Jenkins Job Builder configs
```

**Important:** The `common-packer` directory is typically a Git submodule that must be checked out.

### GitHub Repository Variables

Configure these in your GitHub repository settings (Settings → Secrets and variables → Actions → Variables):

| Variable             | Description             | Example                              |
| -------------------- | ----------------------- | ------------------------------------ |
| `GERRIT_SERVER`      | Gerrit server hostname  | `gerrit.example.com`                 |
| `GERRIT_SSH_USER`    | SSH username for Gerrit | `jenkins`                            |
| `GERRIT_URL`         | Gerrit base URL         | `https://gerrit.example.com/`        |
| `GERRIT_KNOWN_HOSTS` | SSH known_hosts entry   | `gerrit.example.com ssh-rsa AAAA...` |

### GitHub Repository Secrets

Configure these secrets:

| Secret                   | Required For          | Description                           |
| ------------------------ | --------------------- | ------------------------------------- |
| `GERRIT_SSH_PRIVKEY`     | Validation            | SSH private key for Gerrit access     |
| `CLOUD_ENV_JSON_B64`     | Build only            | Base64-encoded cloud environment JSON |
| `CLOUDS_YAML_B64`        | Build only (optional) | Base64-encoded clouds.yaml            |
| `OPENSTACK_AUTH_URL`     | Build only            | OpenStack auth URL                    |
| `OPENSTACK_PROJECT_ID`   | Build only            | OpenStack project ID                  |
| `OPENSTACK_USERNAME`     | Build only            | OpenStack username                    |
| `OPENSTACK_PASSWORD_B64` | Build only            | Base64-encoded password               |
| `OPENSTACK_NETWORK_ID`   | Build only            | Network UUID                          |
| `TAILSCALE_AUTH_KEY`     | Build only            | Tailscale auth key                    |

## Validation Workflow (Gerrit Verify)

Create `.github/workflows/gerrit-verify.yaml`:

```yaml
name: Gerrit Verify

on:
    workflow_dispatch:
        inputs:
            GERRIT_BRANCH:
                required: true
                type: string
            # ... other Gerrit inputs

jobs:
    prepare:
        runs-on: ubuntu-latest
        steps:
            - name: Clear votes
              uses: lfit/gerrit-review-action@v0.8
              with:
                  host: ${{ vars.GERRIT_SERVER }}
                  username: ${{ vars.GERRIT_SSH_USER }}
                  key: ${{ secrets.GERRIT_SSH_PRIVKEY }}
                  known_hosts: ${{ vars.GERRIT_KNOWN_HOSTS }}
                  gerrit-change-number: ${{ inputs.GERRIT_CHANGE_NUMBER }}
                  gerrit-patchset-number: ${{ inputs.GERRIT_PATCHSET_NUMBER }}
                  vote-type: clear

    packer-validator:
        needs: prepare
        runs-on: ubuntu-latest
        steps:
            - name: Checkout Gerrit Change
              uses: lfit/checkout-gerrit-change-action@v0.9
              with:
                  gerrit-refspec: ${{ inputs.GERRIT_REFSPEC }}
                  gerrit-project: ${{ inputs.GERRIT_PROJECT }}
                  gerrit-url: ${{ vars.GERRIT_URL }}
                  submodules: "true" # ← Important!

            - name: Update submodules
              run: git submodule update --init

            - name: Check for packer changes
              uses: dorny/paths-filter@v3
              id: changes
              with:
                  filters: |
                      src:
                        - 'packer/**'

            - name: Validate Packer
              if: steps.changes.outputs.src == 'true'
              uses: lfit/packer-openstack-bastion-action@v1
              with:
                  mode: validate
                  packer_template: "templates/builder.pkr.hcl"
                  packer_vars_file: "common-packer/vars/ubuntu-22.04.pkrvars.hcl"
                  packer_working_dir: "packer"

    vote:
        if: always()
        needs: [prepare, packer-validator]
        runs-on: ubuntu-latest
        steps:
            - uses: im-open/workflow-conclusion@v2.2.3
            - name: Set vote
              uses: lfit/gerrit-review-action@v0.8
              with:
                  host: ${{ vars.GERRIT_SERVER }}
                  username: ${{ vars.GERRIT_SSH_USER }}
                  key: ${{ secrets.GERRIT_SSH_PRIVKEY }}
                  known_hosts: ${{ vars.GERRIT_KNOWN_HOSTS }}
                  gerrit-change-number: ${{ inputs.GERRIT_CHANGE_NUMBER }}
                  gerrit-patchset-number: ${{ inputs.GERRIT_PATCHSET_NUMBER }}
                  vote-type: ${{ env.WORKFLOW_CONCLUSION }}
```

## Build Workflow (Gerrit Merge)

Create `.github/workflows/gerrit-merge.yaml`:

```yaml
name: Gerrit Packer Merge

on:
    workflow_dispatch:
        inputs:
            GERRIT_BRANCH:
                required: true
                type: string
            platform:
                description: "Platform (e.g., ubuntu-22.04)"
                required: true
                type: string
            template:
                description: "Template (e.g., builder)"
                required: true
                type: string

jobs:
    packer-build:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v4
              with:
                  ref: ${{ inputs.GERRIT_BRANCH }}
                  submodules: true

            - run: git submodule update --init

            - name: Build Image
              uses: lfit/packer-openstack-bastion-action@v1
              with:
                  mode: build
                  packer_template: "templates/${{ inputs.template }}.pkr.hcl"
                  packer_vars_file: "common-packer/vars/${{ inputs.platform }}.pkrvars.hcl"
                  packer_working_dir: "packer"
                  cloud_env_json: ${{ secrets.CLOUD_ENV_JSON_B64 }}
                  openstack_auth_url: ${{ secrets.OPENSTACK_AUTH_URL }}
                  # ... other OpenStack secrets
                  tailscale_auth_key: ${{ secrets.TAILSCALE_AUTH_KEY }}
```

## Triggering from Gerrit

### Option 1: Gerrit Trigger Plugin (Jenkins)

If using Jenkins as intermediary:

```groovy
// In JJB or Jenkinsfile
githubActions {
    workflow = 'gerrit-verify.yaml'
    repository = 'org/repo'
    inputs = [
        GERRIT_BRANCH: env.GERRIT_BRANCH,
        GERRIT_CHANGE_ID: env.GERRIT_CHANGE_ID,
        // ... other inputs
    ]
}
```

### Option 2: Gerrit Webhooks

Configure in Gerrit → Project Settings → Webhooks:

**Webhook URL:**

```
https://api.github.com/repos/OWNER/REPO/actions/workflows/gerrit-verify.yaml/dispatches
```

**Headers:**

```
Authorization: Bearer ${GITHUB_PAT}
Accept: application/vnd.github.v3+json
```

**Payload Template:**

```json
{
    "ref": "main",
    "inputs": {
        "GERRIT_BRANCH": "${branch}",
        "GERRIT_CHANGE_ID": "${change-id}",
        "GERRIT_CHANGE_NUMBER": "${change-number}",
        "GERRIT_CHANGE_URL": "${change-url}",
        "GERRIT_EVENT_TYPE": "${event-type}",
        "GERRIT_PATCHSET_NUMBER": "${patchset-number}",
        "GERRIT_PATCHSET_REVISION": "${revision}",
        "GERRIT_PROJECT": "${project}",
        "GERRIT_REFSPEC": "${refspec}"
    }
}
```

## Multiple Platform/Template Combinations

### Using Matrix Strategy

```yaml
jobs:
    packer-build:
        runs-on: ubuntu-latest
        strategy:
            matrix:
                platform: [ubuntu-20.04, ubuntu-22.04, ubuntu-24.04]
                template: [builder, docker, robot]
        steps:
            - uses: actions/checkout@v4
              with:
                  submodules: true
            - run: git submodule update --init
            - uses: lfit/packer-openstack-bastion-action@v1
              with:
                  mode: build
                  packer_template: "templates/${{ matrix.template }}.pkr.hcl"
                  packer_vars_file: "common-packer/vars/${{ matrix.platform }}.pkrvars.hcl"
                  # ... other inputs
```

### Using Workflow Inputs

```yaml
on:
    workflow_dispatch:
        inputs:
            combinations:
                description: "JSON array of [{platform, template}]"
                required: true

jobs:
    generate-matrix:
        runs-on: ubuntu-latest
        outputs:
            matrix: ${{ steps.set-matrix.outputs.matrix }}
        steps:
            - id: set-matrix
              run: echo "matrix=${{ inputs.combinations }}" >> $GITHUB_OUTPUT

    build:
        needs: generate-matrix
        strategy:
            matrix: ${{ fromJson(needs.generate-matrix.outputs.matrix) }}
        # ... rest of job
```

## Validation vs Build Comparison

| Feature               | Validate Mode    | Build Mode         |
| --------------------- | ---------------- | ------------------ |
| **Bastion Host**      | ❌ Not created   | ✅ Created         |
| **Tailscale**         | ❌ Not needed    | ✅ Required        |
| **Cloud Credentials** | ⚠️ Optional      | ✅ Required        |
| **Execution Time**    | ~30 seconds      | ~5-15 minutes      |
| **Cost**              | Minimal          | Moderate (compute) |
| **Use Case**          | Pre-merge checks | Image publishing   |
| **Triggered By**      | Patchset upload  | Merge/Schedule     |

## Troubleshooting

### Validation Fails with "No such file"

**Problem:** Can't find template or vars file

**Solution:**

1. Check `packer_working_dir` is correct
2. Ensure paths are relative to working directory
3. Verify submodules are checked out:

    ```yaml
    - uses: lfit/checkout-gerrit-change-action@v0.9
      with:
          submodules: "true"
    - run: git submodule update --init
    ```

### Build Fails: "tailscale_auth_key is required"

**Problem:** Build mode requires Tailscale but key not provided

**Solution:** Add secret to repository:

```bash
gh secret set TAILSCALE_AUTH_KEY --body "tskey-auth-..."
```

### Gerrit Vote Not Posted

**Problem:** Vote job doesn't run or fails

**Solution:**

1. Check `vote` job has `if: always()`
2. Verify GERRIT_SSH_PRIVKEY secret is set
3. Ensure GERRIT_SERVER variable matches

### Common-packer Submodule Not Found

**Problem:** `common-packer/vars/*.pkrvars.hcl` not found

**Solution:**

```yaml
- uses: lfit/checkout-gerrit-change-action@v0.9
  with:
      submodules: "true" # ← Must be string "true"
- run: git submodule update --init
```

## Best Practices

1. **Always use validate mode for pre-merge** - Fast feedback, no cost
2. **Use build mode sparingly** - Scheduled or post-merge only
3. **Check for changes** - Use paths-filter to skip unchanged files
4. **Matrix builds** - Limit concurrent builds to avoid quota issues
5. **Submodules** - Always checkout and update
6. **Error handling** - Action exits with error code on failure
7. **Voting** - Let workflow handle votes based on job status

## Examples

See `examples/workflows/` directory:

- `gerrit-packer-verify.yaml` - Complete verification workflow
- `gerrit-packer-merge.yaml` - Complete build workflow
- `matrix-build-example.yaml` - Multi-combination builds

## References

- [Gerrit Review Action](https://github.com/lfit/gerrit-review-action)
- [Checkout Gerrit Change Action](https://github.com/lfit/checkout-gerrit-change-action)
- [Gerrit Documentation](https://gerrit-review.googlesource.com/Documentation/)
