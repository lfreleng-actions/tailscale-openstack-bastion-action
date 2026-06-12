<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# OpenStack Bastion with Tailscale Action

<!-- prettier-ignore-start -->
<!-- markdownlint-disable-next-line MD013 -->
[![Linux Foundation](https://img.shields.io/badge/Linux-Foundation-blue)](https://linuxfoundation.org/) [![Source Code](https://img.shields.io/badge/GitHub-100000?logo=github&logoColor=white&color=blue)](https://github.com/lfreleng-actions/tailscale-openstack-bastion-action) [![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) [![pre-commit.ci status badge]][pre-commit.ci results page] [![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/lfreleng-actions/tailscale-openstack-bastion-action/badge)](https://scorecard.dev/viewer/?uri=github.com/lfreleng-actions/tailscale-openstack-bastion-action)
<!-- prettier-ignore-end -->

A GitHub Action to setup and teardown OpenStack bastion hosts with Tailscale VPN for secure remote access. This action creates ephemeral bastion hosts that connect to your Tailscale network, enabling secure SSH access to OpenStack instances from GitHub Actions runners.

## Features

- 🔒 **Secure Access**: Uses Tailscale VPN for encrypted, zero-trust networking
- ☁️ **Cloud-Native**: Built for OpenStack cloud environments
- ⚡ **Ephemeral**: Automatic bastion creation and cleanup
- 🛡️ **Fail-Safe**: Automatic cleanup on timeout or failure
- 🔑 **Flexible Auth**: Supports both OAuth (recommended) and legacy auth keys
- 📊 **Detailed Logging**: Comprehensive logs for debugging

## Architecture

### Component Diagram

```mermaid
graph TB
    subgraph GitHub["🖥️ GitHub Actions Runner"]
        Packer["Packer<br/>Installed"]
        RunnerTS["Tailscale VPN<br/>Connected<br/>(tag:ci)"]
        Packer --> RunnerTS
    end

    subgraph Tailscale["☁️ Tailscale Mesh Network"]
        VPN["Secure WireGuard Tunnel"]
    end

    RunnerTS -.->|🔒 Encrypted<br/>Connection| VPN

    subgraph OpenStack["🌐 OpenStack Cloud"]
        subgraph Bastion["⚡ Bastion Host (Ephemeral)"]
            BastionTS["Tailscale Agent<br/>(tag:bastion)"]
            PackerOpt["Packer<br/>(Optional)"]
            CloudInit["Cloud-init:<br/>Tailscale + Packer +<br/>Network Config"]
            BastionTS ~~~ PackerOpt
            BastionTS ~~~ CloudInit
        end

        Resources["🎯 Build Target<br/>Infrastructure"]
        Bastion --> Resources
    end

    VPN -.->|🔒 Encrypted<br/>Connection| BastionTS

    %% Modern color scheme with better contrast
    style GitHub fill:#bbdefb,stroke:#1565c0,stroke-width:3px,color:#000
    style OpenStack fill:#ffccbc,stroke:#d84315,stroke-width:3px,color:#000
    style Tailscale fill:#e1bee7,stroke:#6a1b9a,stroke-width:3px,color:#000
    style Bastion fill:#c8e6c9,stroke:#2e7d32,stroke-width:3px,color:#000
    style VPN fill:#d1c4e9,stroke:#4527a0,stroke-width:3px,color:#000
    style Packer fill:#fff9c4,stroke:#f57f17,stroke-width:2px,color:#000
    style RunnerTS fill:#b3e5fc,stroke:#0277bd,stroke-width:2px,color:#000
    style BastionTS fill:#a5d6a7,stroke:#388e3c,stroke-width:2px,color:#000
    style Resources fill:#ffab91,stroke:#bf360c,stroke-width:2px,color:#000
```

### Workflow

```mermaid
graph TD
    A[GitHub Actions Triggered] --> B[Setup Packer & Python]
    B --> C[Connect to Tailscale VPN]
    C --> D[Configure OpenStack CLI]
    D --> E[Generate Cloud-Init Script]
    E --> F[Launch Bastion on OpenStack]
    F --> G{Bastion Joins Tailscale?}
    G -->|Yes| H[Get Bastion IP]
    G -->|Timeout| Z[Show Logs & Fail]
    H --> I{Ready Marker Found?}
    I -->|Yes| J[Initialize Packer]
    I -->|No| K[Wait & Retry]
    K --> I
    J --> L[Validate Templates]
    L --> M[Build Images via Bastion]
    M --> N[Upload Artifacts]
    N --> O[Delete Bastion]
    O --> P[Workflow Complete]
    Z --> O
```

**Key Stages**:

1. **GitHub Runner Setup** → Install dependencies & connect to Tailscale
2. **Bastion Launch** → Spin up ephemeral VM on OpenStack with cloud-init
3. **Network Mesh** → Bastion joins Tailscale, creates secure tunnel
4. **Build Execution** → Execute builds via bastion proxy
5. **Cleanup** → Destroy bastion, disconnect from Tailscale

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed architecture documentation.

## Prerequisites

- OpenStack cloud account with necessary permissions
- Tailscale account with configured ACLs
- GitHub repository secrets configured (see Configuration section)

## Usage

### Basic Setup and Teardown

```yaml
jobs:
    my-job:
        runs-on: ubuntu-latest
        steps:
            # Setup bastion
            - name: Setup bastion
              id: bastion
              uses: lfreleng-actions/tailscale-openstack-bastion-action@6215d35becaf155eb6c523f339ce7f2647b69812 # main
              with:
                  operation: setup
                  openstack_auth_url: ${{ secrets.OPENSTACK_AUTH_URL }}
                  openstack_project_id: ${{ secrets.OPENSTACK_PROJECT_ID }}
                  openstack_username: ${{ secrets.OPENSTACK_USERNAME }}
                  openstack_password: ${{ secrets.OPENSTACK_PASSWORD }}
                  tailscale_oauth_client_id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
                  tailscale_oauth_secret: ${{ secrets.TAILSCALE_OAUTH_SECRET }}

            # Use bastion
            - name: Use bastion for remote operations
              run: |
                  echo "Bastion IP: ${{ steps.bastion.outputs.bastion_ip }}"
                  # Your operations here

            # Always cleanup
            - name: Cleanup bastion
              if: always()
              uses: lfreleng-actions/tailscale-openstack-bastion-action@6215d35becaf155eb6c523f339ce7f2647b69812 # main
              with:
                  operation: teardown
                  bastion_name: ${{ steps.bastion.outputs.bastion_name }}
                  openstack_auth_url: ${{ secrets.OPENSTACK_AUTH_URL }}
                  openstack_project_id: ${{ secrets.OPENSTACK_PROJECT_ID }}
                  openstack_username: ${{ secrets.OPENSTACK_USERNAME }}
                  openstack_password: ${{ secrets.OPENSTACK_PASSWORD }}
```

### With Custom Configuration

```yaml
- name: Setup bastion with custom settings
  uses: lfreleng-actions/tailscale-openstack-bastion-action@6215d35becaf155eb6c523f339ce7f2647b69812 # main
  with:
      operation: setup
      bastion_flavor: v3-standard-4
      bastion_image: "Ubuntu 24.04 LTS"
      bastion_network: custom-network
      bastion_wait_timeout: 600
      tailscale_tags: tag:ci,tag:bastion
      debug_mode: true
      # ... OpenStack credentials
```

## Inputs

### Required Inputs

| Input                  | Description                                  |
| ---------------------- | -------------------------------------------- |
| `operation`            | Operation to perform: `setup` or `teardown`  |
| `openstack_auth_url`   | OpenStack authentication URL                 |
| `openstack_project_id` | OpenStack project/tenant ID                  |
| `openstack_username`   | OpenStack username                           |
| `openstack_password`   | OpenStack password (base64 encoded or plain) |

### Tailscale Authentication (for setup operation)

**Option 1: OAuth with Ephemeral Keys (Recommended)**

The recommended approach uses OAuth to generate short-lived, ephemeral auth keys for the bastion host:

| Input                          | Description                                          |
| ------------------------------ | ---------------------------------------------------- |
| `tailscale_oauth_client_id`    | Tailscale OAuth client ID                            |
| `tailscale_oauth_secret`       | Tailscale OAuth client secret                        |
| `tailscale_use_ephemeral_keys` | Generate ephemeral keys from OAuth (default: `true`) |

**How it works:**

1. GitHub runner connects to Tailscale using OAuth credentials
2. Action generates a short-lived (1 hour), ephemeral auth key via Tailscale API
3. Action injects the ephemeral key into bastion cloud-init for secure, one-time use
4. Bastion automatically removed from Tailscale when destroyed

**Benefits:**

- ✅ No static auth keys to manage or rotate
- ✅ Automatic cleanup of bastion devices from Tailscale
- ✅ Short-lived credentials (1 hour expiry)
- ✅ Ephemeral devices don't persist in your tailnet
- ✅ Follows Tailscale security best practices

**Option 2: Direct OAuth (GitHub Runner)**

The GitHub runner can authenticate with OAuth directly, but the bastion still requires a static auth key:

| Input                          | Description                                        |
| ------------------------------ | -------------------------------------------------- |
| `tailscale_oauth_client_id`    | Tailscale OAuth client ID (for runner)             |
| `tailscale_oauth_secret`       | Tailscale OAuth client secret (for runner)         |
| `tailscale_auth_key`           | Static auth key for bastion host                   |
| `tailscale_use_ephemeral_keys` | Set to `false` to disable ephemeral key generation |

**Option 3: Auth Key (Legacy)**

Both runner and bastion use the same static auth key:

| Input                | Description                                                |
| -------------------- | ---------------------------------------------------------- |
| `tailscale_auth_key` | Tailscale authentication key (for both runner and bastion) |

**⚠️ Not recommended:** Requires managing static auth keys and manual device cleanup.

### Optional Inputs

| Input                  | Description            | Default                                    |
| ---------------------- | ---------------------- | ------------------------------------------ |
| `openstack_region`     | OpenStack region       | `ca-ymq-1`                                 |
| `openstack_network_id` | OpenStack network UUID | ``                                         |
| `bastion_flavor`       | Instance flavor        | `v3-standard-2`                            |
| `bastion_image`        | Base image name        | `Ubuntu 22.04.5 LTS (x86_64) [2025-03-27]` |
| `bastion_network`      | Network name           | `odlci`                                    |
| `bastion_ssh_key`      | SSH key name           | ``                                         |
| `bastion_wait_timeout` | Timeout in seconds     | `300`                                      |
| `bastion_name`         | Custom bastion name    | `bastion-gh-{run_id}`                      |
| `tailscale_tags`       | Tailscale tags         | `tag:ci`                                   |
| `tailscale_version`    | Tailscale version      | `latest`                                   |
| `debug_mode`           | Enable debug logging   | `false`                                    |

## Outputs

| Output         | Description                               |
| -------------- | ----------------------------------------- |
| `bastion_ip`   | Tailscale IP address of the bastion host  |
| `bastion_name` | Name of the bastion instance              |
| `status`       | Operation status (`success` or `failure`) |

## Configuration

### GitHub Secrets

Configure these secrets in your GitHub repository:

#### Required Secrets

- `OPENSTACK_AUTH_URL`: OpenStack authentication endpoint
- `OPENSTACK_PROJECT_ID`: OpenStack project/tenant ID
- `OPENSTACK_USERNAME`: OpenStack username
- `OPENSTACK_PASSWORD` or `OPENSTACK_PASSWORD_B64`: OpenStack password (plain or base64 encoded)

#### Tailscale Secrets (choose one method)

**OAuth Method (Recommended)**

- `TAILSCALE_OAUTH_CLIENT_ID`: OAuth client ID
- `TAILSCALE_OAUTH_SECRET`: OAuth client secret

**Auth Key Method (Legacy)**

- `TAILSCALE_AUTH_KEY`: Authentication key

### Tailscale ACL Configuration

Your Tailscale ACL must include:

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

See [Tailscale Setup Guide](docs/TAILSCALE_SETUP.md) for detailed configuration.

## How It Works

1. **Setup Operation**:

    - Connects GitHub Actions runner to Tailscale network
    - Creates cloud-init configuration with Tailscale setup
    - Launches OpenStack instance with cloud-init
    - Waits for bastion to join Tailscale network
    - Returns bastion Tailscale IP for secure access
    - Automatic cleanup if setup times out

2. **Teardown Operation**:
    - Deletes the OpenStack bastion instance
    - Verifies successful deletion

## Examples

See the [examples/workflows](examples/workflows/) directory for complete workflow examples.

## Development

See [DEVELOPMENT.md](docs/DEVELOPMENT.md) for development and testing guidelines.

## License

Apache License 2.0 - See [LICENSE](LICENSE) for details.

## Testing

This action includes comprehensive test workflows to validate functionality:

### Test Workflows

1. **test-bastion-setup.yaml** - Complete lifecycle test

    - Tests bastion setup with OAuth authentication
    - Validates connectivity and SSH access
    - Tests network connectivity from bastion
    - Verifies proper teardown and cleanup
    - Run manually via workflow_dispatch or automatically on push/PR

2. **test-authkey.yaml** - Legacy authentication test

    - Tests bastion setup with legacy auth keys
    - Validates backward compatibility
    - Run manually via workflow_dispatch

3. **test-error-handling.yaml** - Error scenario tests
    - Tests timeout behavior and auto-cleanup
    - Tests invalid credentials handling
    - Tests missing Tailscale authentication
    - Run manually via workflow_dispatch with scenario selection

### Running Tests Locally

To run tests manually:

```bash
# Run complete setup/teardown test
gh workflow run test-bastion-setup.yaml

# Run auth key compatibility test
gh workflow run test-authkey.yaml

# Run error handling tests
gh workflow run test-error-handling.yaml -f test_scenario=timeout
gh workflow run test-error-handling.yaml -f test_scenario=invalid_credentials
gh workflow run test-error-handling.yaml -f test_scenario=network_error
```

### Test Coverage

The test suite validates:

- ✅ Bastion host creation and initialization
- ✅ Tailscale network connectivity (OAuth and auth key methods)
- ✅ SSH connectivity and command execution
- ✅ Network connectivity from bastion
- ✅ Proper cleanup and resource deletion
- ✅ Timeout handling and auto-cleanup
- ✅ Error handling for invalid credentials
- ✅ Graceful failure scenarios

## Support

For issues, questions, or contributions, please open an issue in the repository.

[pre-commit.ci results page]: https://results.pre-commit.ci/latest/github/lfreleng-actions/tailscale-openstack-bastion-action/main
[pre-commit.ci status badge]: https://results.pre-commit.ci/badge/github/lfreleng-actions/tailscale-openstack-bastion-action/main.svg
