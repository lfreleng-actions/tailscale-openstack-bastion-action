# Gerrit-to-GitHub Integration Guide

This document explains how Gerrit events trigger GitHub Actions workflows using the `gerrit-to-platform` system.

## Overview

The `gerrit-to-platform` system automatically discovers and triggers GitHub Actions workflows when Gerrit events occur (patchset creation, change merge, etc.). It uses a filename-based convention to identify which workflows to trigger for each event type.

## Workflow Discovery Mechanism

### Filename Convention

The system identifies workflows to trigger based on their filenames. Workflows must follow this naming pattern:

```
gerrit-<event-type>-<description>.yaml
```

Where:

- **gerrit**: Required prefix - all workflows must contain "gerrit" in the filename
- **event-type**: The Gerrit event type (e.g., "verify", "merge")
- **description**: Optional descriptive name (e.g., "packer", "build", etc.)

### Event Types

1. **Verify Events** (patchset-created, comment-added with verify vote)

    - Triggered when a new patchset is uploaded or verification is requested
    - Workflow filenames must contain: `gerrit` AND `verify`
    - Example: `gerrit-packer-verify.yaml`

2. **Merge Events** (change-merged)
    - Triggered when a change is merged to the target branch
    - Workflow filenames must contain: `gerrit` AND `merge`
    - Example: `gerrit-packer-merge.yaml`

### Workflow Location

Workflows can be placed in two locations:

1. **Repository-specific workflows** (`.github/workflows/` in the target repo)

    - Triggered for events in that specific repository
    - Most common use case

2. **Organization-wide required workflows** (`.github/workflows/` in the `.github` repo)
    - Must also contain "required" in the filename
    - Triggered for events across all repositories in the organization
    - Receive `TARGET_REPO` input parameter with the actual repository name

## Required Workflow Structure

### Trigger Configuration

All Gerrit-triggered workflows must use `workflow_dispatch` trigger:

```yaml
name: Gerrit Packer Verify
on:
    workflow_dispatch:
        inputs:
            GERRIT_BRANCH:
                description: "Branch that change is against"
                required: true
                type: string
            GERRIT_CHANGE_ID:
                description: "The ID for the change"
                required: true
                type: string
            GERRIT_CHANGE_NUMBER:
                description: "The Gerrit number"
                required: true
                type: string
            GERRIT_CHANGE_URL:
                description: "URL to the change"
                required: true
                type: string
            GERRIT_EVENT_TYPE:
                description: "Type of Gerrit event"
                required: true
                type: string
            GERRIT_PATCHSET_NUMBER:
                description: "The patch number for the change"
                required: true
                type: string
            GERRIT_PATCHSET_REVISION:
                description: "The revision sha"
                required: true
                type: string
            GERRIT_PROJECT:
                description: "Project in Gerrit"
                required: true
                type: string
            GERRIT_REFSPEC:
                description: "Gerrit refspec of change"
                required: true
                type: string
            # For required workflows in .github repo only:
            TARGET_REPO:
                description: "The target GitHub repository needing the required workflow"
                required: false
                type: string
```

### Checkout Pattern

To work with the actual change/patchset, workflows must fetch the Gerrit refspec:

```yaml
- name: Checkout repository
  uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
  with:
      repository: ${{ github.repository }}
      ref: ${{ inputs.GERRIT_BRANCH }}
      fetch-depth: 0
      submodules: recursive

- name: Fetch and checkout Gerrit patchset
  run: |
      git fetch origin ${{ inputs.GERRIT_REFSPEC }}
      git checkout FETCH_HEAD
```

For required workflows in the `.github` repo, use `TARGET_REPO` input:

```yaml
- name: Checkout target repository
  uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
  with:
      repository: ${{ inputs.TARGET_REPO }}
      ref: ${{ inputs.GERRIT_BRANCH }}
      fetch-depth: 0
      submodules: recursive

- name: Fetch and checkout Gerrit patchset
  run: |
      git fetch origin ${{ inputs.GERRIT_REFSPEC }}
      git checkout FETCH_HEAD
```

## Workflow Filtering Process

The `gerrit-to-platform` system uses the following logic to discover workflows:

1. List all active workflows in the target repository
2. Filter for workflows containing "gerrit" in the path/filename (case-insensitive)
3. Filter for workflows containing the event type ("verify" or "merge") in the path/filename
4. Filter out workflows containing "required" (for repository-specific workflows)
5. Dispatch each matching workflow with Gerrit event inputs

For the `.github` magic repo:
1-3. Same as above 4. Filter FOR workflows containing "required" 5. Add `TARGET_REPO` input and dispatch

## Example Workflows

### Verify Workflow

```yaml
name: Gerrit Packer Verify
on:
    workflow_dispatch:
        inputs:
            GERRIT_BRANCH:
                required: true
                type: string
            # ... other Gerrit inputs ...

jobs:
    detect-changes:
        runs-on: ubuntu-latest
        outputs:
            changed_files: ${{ steps.changes.outputs.all_changed_files }}
        steps:
            - name: Checkout
              uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
              with:
                  ref: ${{ inputs.GERRIT_BRANCH }}
                  fetch-depth: 0

            - name: Fetch Gerrit patchset
              run: |
                  git fetch origin ${{ inputs.GERRIT_REFSPEC }}
                  git checkout FETCH_HEAD

            - name: Detect changed packer files
              id: changes
              uses: tj-actions/changed-files@c3a1bb2c992d77180ae65be6ae6c166cf40f857c # v45.0.3
              with:
                  files: |
                      templates/**/*.pkr.hcl
                      vars/**/*.pkrvars.hcl

    validate:
        needs: detect-changes
        if: needs.detect-changes.outputs.changed_files != ''
        runs-on: ubuntu-latest
        steps:
            - name: Run validation
              uses: lfit/releng-packer-action@main
              with:
                  mode: validate
                  # ... other inputs ...
```

### Merge Workflow

```yaml
name: Gerrit Packer Merge
on:
    workflow_dispatch:
        inputs:
            GERRIT_BRANCH:
                required: true
                type: string
            # ... other Gerrit inputs ...
    schedule:
        - cron: "0 0 1 * *" # Monthly rebuild

jobs:
    setup-matrix:
        runs-on: ubuntu-latest
        outputs:
            matrix: ${{ steps.set-matrix.outputs.matrix }}
        steps:
            - name: Determine build strategy
              id: set-matrix
              run: |
                  if [ "${{ github.event_name }}" = "schedule" ]; then
                    # Monthly: build all templates
                    MATRIX='{"include":[{"template":"builder","os":"ubuntu-22.04"},...]}'
                  else
                    # Merge: detect changed files and build only those
                    # Use changed-files action similar to verify workflow
                  fi
                  echo "matrix=$MATRIX" >> $GITHUB_OUTPUT

    build:
        needs: setup-matrix
        runs-on: ubuntu-latest
        strategy:
            matrix: ${{ fromJson(needs.setup-matrix.outputs.matrix) }}
        steps:
            - name: Run packer build
              uses: lfit/releng-packer-action@main
              with:
                  mode: build
                  # ... other inputs ...
```

## Repository Setup Requirements

To enable Gerrit-to-GitHub integration in a repository:

### 1. GitHub Repository Configuration

- Repository must be a mirror/replica of the Gerrit repository
- Must have Actions enabled
- Must have appropriate secrets configured (cloud credentials, Tailscale tokens, etc.)

### 2. Gerrit Configuration

The Gerrit server must be configured with:

- `gerrit-to-platform` hook installed
- Replication plugin configured to mirror to GitHub
- Hook must be configured with GitHub token and repository mapping

### 3. Required Secrets

Repository secrets needed (inherit from organization or set per-repository):

```yaml
# OpenStack/Cloud Provider
OPENSTACK_AUTH_URL
OPENSTACK_PASSWORD
OPENSTACK_PROJECT_ID
OPENSTACK_USERNAME
OPENSTACK_NETWORK

# Tailscale (for bastion host)
TAILSCALE_OAUTH_CLIENT_ID
TAILSCALE_OAUTH_SECRET

# Optional: if using auth keys instead of OAuth
TAILSCALE_AUTHKEY
```

### 4. Workflow Files

Copy example workflows from this repository:

- `examples/workflows/gerrit-packer-verify.yaml` → `.github/workflows/`
- `examples/workflows/gerrit-packer-merge.yaml` → `.github/workflows/`

Customize as needed for your repository structure.

## Testing

### Manual Testing

You can manually trigger workflows to test them:

```bash
gh workflow run gerrit-packer-verify.yaml \
  -f GERRIT_BRANCH=main \
  -f GERRIT_CHANGE_ID=I1234567890abcdef1234567890abcdef12345678 \
  -f GERRIT_CHANGE_NUMBER=12345 \
  -f GERRIT_CHANGE_URL=https://gerrit.example.org/c/project/+/12345 \
  -f GERRIT_EVENT_TYPE=patchset-created \
  -f GERRIT_PATCHSET_NUMBER=1 \
  -f GERRIT_PATCHSET_REVISION=abcdef1234567890abcdef1234567890abcdef12 \
  -f GERRIT_PROJECT=releng/builder \
  -f GERRIT_REFSPEC=refs/changes/45/12345/1
```

### Verification Checklist

- [ ] Workflow filenames follow the convention (`gerrit-*-verify.yaml` or `gerrit-*-merge.yaml`)
- [ ] Workflows use `workflow_dispatch` trigger
- [ ] All required Gerrit inputs are defined
- [ ] Checkout fetches the Gerrit refspec correctly
- [ ] Submodules are checked out if needed (`submodules: recursive`)
- [ ] Required secrets are configured
- [ ] Workflows complete successfully with manual trigger

## Troubleshooting

### Workflow Not Being Triggered

1. **Check filename**: Must contain "gerrit" and event type ("verify" or "merge")
2. **Check workflow state**: Must be "active" in GitHub (not disabled)
3. **Check gerrit-to-platform logs**: Look for dispatch messages
4. **Check GitHub Actions**: Look for workflow run attempts

### Checkout Issues

1. **Submodules not checked out**: Add `submodules: recursive` to checkout action
2. **Wrong ref checked out**: Ensure you fetch and checkout `GERRIT_REFSPEC`
3. **Permission issues**: Check repository access token permissions

### Build Failures

1. **Missing secrets**: Verify all required secrets are configured
2. **Bastion host issues**: Check Tailscale ACLs and OAuth client configuration
3. **Packer validation fails**: Run validation locally first with `-syntax-only`

## References

- [gerrit-to-platform documentation](https://gerrit-to-platform.readthedocs.io/)
- [GitHub Actions workflow_dispatch](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_dispatch)
- [Gerrit hooks](https://gerrit-review.googlesource.com/Documentation/config-hooks.html)
- [Tailscale ACLs](https://tailscale.com/kb/1018/acls)

## Support

For issues or questions:

- File an issue in the [releng-packer-action repository](https://github.com/lfit/releng-packer-action)
- Contact the LF Release Engineering team
