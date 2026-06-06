#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
##############################################################################
# Copyright (c) 2025 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# https://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -euo pipefail

# Script: bastion-manager.sh
# Purpose: Manage OpenStack bastion host lifecycle (setup/teardown)
# Features:
#   - Create/destroy OpenStack instances
#   - Configure Tailscale VPN
#   - Wait for bastion readiness with automatic cleanup on timeout
#   - Export bastion details for downstream jobs

#============================================================================
# Configuration and Defaults
#============================================================================

MODE="${MODE:-setup}"
DEBUG="${DEBUG:-false}"

# OpenStack settings
OS_FLAVOR="${OS_FLAVOR:-m1.small}"
OS_IMAGE="${OS_IMAGE:-Ubuntu 22.04}"
OS_FLOATING_IP_POOL="${OS_FLOATING_IP_POOL:-public}"
OS_SECURITY_GROUPS="${OS_SECURITY_GROUPS:-default}"

# Bastion settings
BASTION_PREFIX="${BASTION_PREFIX:-bastion-gh}"
BASTION_NAME="${BASTION_NAME:-${BASTION_PREFIX}-${GITHUB_RUN_ID:-$(date +%s)}}"
CONNECTION_TIMEOUT="${CONNECTION_TIMEOUT:-300}"
READY_CHECK_INTERVAL="${READY_CHECK_INTERVAL:-10}"

# Tailscale settings
TS_HOSTNAME="${TS_HOSTNAME:-${BASTION_NAME}}"
TS_TAGS="${TS_TAGS:-tag:ci,tag:bastion}"

#============================================================================
# Helper Functions
#============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

log_debug() {
    if [[ "${DEBUG}" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: $*"
    fi
}

# Export output variable for GitHub Actions
set_output() {
    local name=$1
    local value=$2
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "${name}=${value}" >> "$GITHUB_OUTPUT"
    fi
    log_debug "Output: ${name}=${value}"
}

# Cleanup function - called on exit
# shellcheck disable=SC2329  # invoked via trap on EXIT
cleanup_on_failure() {
    local exit_code=$?
    if [[ $exit_code -ne 0 && "${MODE}" == "setup" ]]; then
        log_error "Setup failed with exit code ${exit_code}, triggering cleanup..."
        teardown_bastion
    fi
}

trap cleanup_on_failure EXIT

#============================================================================
# Cloud-init Template
#============================================================================

create_cloud_init() {
    local auth_method=""

    # Determine auth method - OAuth preferred over authkey
    if [[ -n "${TS_OAUTH_CLIENT_ID:-}" && -n "${TS_OAUTH_SECRET:-}" ]]; then
        auth_method="--auth-key=\$(curl -s -u \"${TS_OAUTH_CLIENT_ID}:${TS_OAUTH_SECRET}\" 'https://api.tailscale.com/api/v2/tailnet/-/keys' -X POST -H 'Content-Type: application/json' -d '{\"capabilities\":{\"devices\":{\"create\":{\"reusable\":false,\"ephemeral\":true,\"tags\":[\"tag:bastion\",\"tag:ci\"]}}}}' | jq -r '.key')"
    elif [[ -n "${TS_AUTHKEY:-}" ]]; then
        auth_method="--authkey=${TS_AUTHKEY}"
    else
        log_error "No Tailscale authentication method provided"
        return 1
    fi

    cat > "${CLOUD_INIT_FILE}" <<EOFCI
#cloud-config
hostname: ${TS_HOSTNAME}
manage_etc_hosts: true

package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - jq
  - net-tools
  - iputils-ping
  - ca-certificates
  - python3
  - python3-pip

write_files:
  - path: /etc/sysctl.d/99-tailscale.conf
    content: |
      net.ipv4.ip_forward = 1
      net.ipv6.conf.all.forwarding = 1
      net.netfilter.nf_conntrack_max = 131072
    permissions: '0644'

  - path: /usr/local/bin/bastion-init.sh
    content: |
      #!/bin/bash
      set -e
      LOG="/var/log/bastion-init.log"

      log_msg() {
          echo "[\$(date)] \$*" | tee -a "\$LOG"
      }

      log_msg "=== Bastion initialization started ==="

      # Wait for network
      log_msg "Waiting for network connectivity..."
      until ping -c 1 8.8.8.8 &>/dev/null; do
          log_msg "Network not ready, retrying..."
          sleep 2
      done
      log_msg "Network ready"

      # Install Tailscale
      log_msg "Installing Tailscale..."
      curl -fsSL https://tailscale.com/install.sh | sh

      # Start Tailscale
      log_msg "Starting Tailscale..."
      tailscale up \\
        ${auth_method} \\
        --hostname="${TS_HOSTNAME}" \\
        --advertise-tags=${TS_TAGS} \\
        --ssh \\
        --accept-routes \\
        --accept-dns=false

      TAILSCALE_IP=\$(tailscale ip -4 2>/dev/null || echo "")
      if [[ -n "\$TAILSCALE_IP" ]]; then
          log_msg "✅ Tailscale connected: \${TAILSCALE_IP}"
      else
          log_msg "⚠️  Tailscale started but IP not immediately available"
      fi

      # Create ready marker
      echo "READY" > /tmp/bastion-ready
      log_msg "=== Bastion ready ==="

      # Display status banner
      cat <<EOF

      ╔═══════════════════════════════════════════╗
      ║   Bastion host initialization completed   ║
      ║   System uptime: \$(uptime -p)
      ║   Cloud-init took \${SECONDS}s             ║
      ╚═══════════════════════════════════════════╝

      Check /var/log/bastion-init.log for detailed logs.
      Check /tmp/bastion-ready to verify bastion is ready.

EOF
    permissions: '0755'

  - path: /etc/motd
    content: |
      ╔═══════════════════════════════════════════╗
      ║   OpenStack Tailscale Bastion Host        ║
      ║   GitHub Actions CI/CD Environment        ║
      ╚═══════════════════════════════════════════╝
      Hostname: ${TS_HOSTNAME}
      Logs: /var/log/bastion-init.log
    permissions: '0644'

timezone: UTC

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    groups: sudo
    lock_passwd: true

ssh_pwauth: false
disable_root: false

runcmd:
  - sysctl -p /etc/sysctl.d/99-tailscale.conf
  - /usr/local/bin/bastion-init.sh

final_message: "Bastion initialization complete after \$UPTIME seconds"
EOFCI

    log "Cloud-init configuration created at ${CLOUD_INIT_FILE}"
}

#============================================================================
# Bastion Setup
#============================================================================

setup_bastion() {
    log "========================================="
    log "Setting up bastion host: ${BASTION_NAME}"
    log "========================================="

    # Validate required inputs
    if [[ -z "${OS_AUTH_URL:-}" ]]; then
        log_error "OS_AUTH_URL is required"
        return 1
    fi

    if [[ -z "${OS_PROJECT_ID:-}" ]]; then
        log_error "OS_PROJECT_ID is required"
        return 1
    fi

    if [[ -z "${OS_NETWORK:-}" ]]; then
        log_error "OS_NETWORK is required"
        return 1
    fi

    # Create cloud-init file
    CLOUD_INIT_FILE=$(mktemp --suffix=.yaml)
    log_debug "Using temporary cloud-init file: ${CLOUD_INIT_FILE}"
    create_cloud_init

    # Build OpenStack server create command
    local cmd="openstack server create"
    cmd="${cmd} --flavor '${OS_FLAVOR}'"
    cmd="${cmd} --image '${OS_IMAGE}'"
    cmd="${cmd} --nic net-id=${OS_NETWORK}"

    # Add SSH key if specified
    if [[ -n "${OS_SSH_KEY:-}" ]]; then
        cmd="${cmd} --key-name ${OS_SSH_KEY}"
        log "Using SSH key: ${OS_SSH_KEY}"
    else
        log "No SSH key specified - using Tailscale SSH only"
    fi

    # Add security groups
    if [[ -n "${OS_SECURITY_GROUPS}" ]]; then
        IFS=',' read -ra GROUPS <<< "${OS_SECURITY_GROUPS}"
        for group in "${GROUPS[@]}"; do
            cmd="${cmd} --security-group ${group}"
        done
    fi

    cmd="${cmd} --user-data ${CLOUD_INIT_FILE}"
    cmd="${cmd} --wait"
    cmd="${cmd} '${BASTION_NAME}'"

    log "Launching bastion instance..."
    log_debug "Command: ${cmd}"

    if eval "${cmd}"; then
        log "✅ Bastion instance created successfully"
    else
        log_error "Failed to create bastion instance"
        rm -f "${CLOUD_INIT_FILE}"
        return 1
    fi

    # Clean up cloud-init file
    rm -f "${CLOUD_INIT_FILE}"

    # Get instance ID
    local bastion_id
    bastion_id=$(openstack server show "${BASTION_NAME}" -f value -c id)
    set_output "bastion_id" "${bastion_id}"
    set_output "bastion_name" "${BASTION_NAME}"

    log "Bastion ID: ${bastion_id}"

    # Wait for bastion to join Tailscale and be ready
    wait_for_bastion_ready

    return $?
}

#============================================================================
# Wait for Bastion Ready
#============================================================================

wait_for_bastion_ready() {
    log "========================================="
    log "Waiting for bastion to join Tailscale..."
    log "Timeout: ${CONNECTION_TIMEOUT}s"
    log "Check interval: ${READY_CHECK_INTERVAL}s"
    log "========================================="

    local elapsed=0
    local max_attempts=$((CONNECTION_TIMEOUT / READY_CHECK_INTERVAL))
    local attempt=0
    local bastion_ip=""

    while [[ $attempt -lt $max_attempts ]]; do
        attempt=$((attempt + 1))
        elapsed=$((attempt * READY_CHECK_INTERVAL))

        log "Checking bastion status (attempt ${attempt}/${max_attempts}, ${elapsed}s elapsed)..."

        # Check if bastion appears in Tailscale network
        if command -v tailscale &>/dev/null; then
            bastion_ip=$(sudo tailscale status --json 2>/dev/null | \
                jq -r --arg hostname "${TS_HOSTNAME}" \
                '.Peer[] | select(.HostName == $hostname) | .TailscaleIPs[0]' 2>/dev/null || echo "")

            if [[ -n "${bastion_ip}" ]]; then
                log "✅ Bastion found in Tailscale network: ${bastion_ip}"
                set_output "bastion_ip" "${bastion_ip}"

                # Try to check ready marker via SSH
                log "Checking bastion ready marker..."
                if timeout 10 ssh -o StrictHostKeyChecking=no \
                    -o UserKnownHostsFile=/dev/null \
                    -o ConnectTimeout=5 \
                    "ubuntu@${bastion_ip}" \
                    "test -f /tmp/bastion-ready" 2>/dev/null; then

                    log "✅ Bastion ready marker found!"
                    log "========================================="
                    log "=== Bastion Status ==="
                    log "Hostname: ${TS_HOSTNAME}"
                    log "Tailscale IP: ${bastion_ip}"
                    log "========================================="
                    set_output "status" "success"
                    return 0
                else
                    log "⚠️ Bastion reachable but ready marker not found, waiting..."
                fi
            else
                log "⏳ Bastion not yet visible in Tailscale network..."
            fi
        else
            log_error "Tailscale command not available on runner"
            set_output "status" "failed"
            return 1
        fi

        sleep "${READY_CHECK_INTERVAL}"
    done

    # Timeout reached
    log_error "========================================="
    log_error "Timeout waiting for bastion to be ready!"
    log_error "Elapsed time: ${elapsed}s"
    log_error "========================================="

    # Capture bastion logs for debugging
    if [[ -n "${bastion_ip}" ]]; then
        log "Attempting to capture bastion logs..."
        timeout 10 ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "ubuntu@${bastion_ip}" \
            "cat /var/log/bastion-init.log 2>/dev/null || cat /var/log/cloud-init-output.log 2>/dev/null" \
            2>&1 || log_error "Failed to retrieve bastion logs"
    fi

    set_output "status" "failed"

    # Trigger automatic cleanup
    log "Triggering automatic cleanup due to timeout..."
    teardown_bastion

    return 1
}

#============================================================================
# Bastion Teardown
#============================================================================

teardown_bastion() {
    log "========================================="
    log "Tearing down bastion host: ${BASTION_NAME}"
    log "========================================="

    # Check if bastion exists
    if ! openstack server show "${BASTION_NAME}" &>/dev/null; then
        log "Bastion '${BASTION_NAME}' not found, nothing to teardown"
        set_output "status" "success"
        return 0
    fi

    log "Deleting bastion instance..."
    if openstack server delete --wait "${BASTION_NAME}"; then
        log "✅ Bastion instance deleted successfully"
        set_output "status" "success"
        return 0
    else
        log_error "Failed to delete bastion instance"
        set_output "status" "failed"
        return 1
    fi
}

#============================================================================
# Main
#============================================================================

main() {
    log "Bastion Manager - Mode: ${MODE}"
    log "Debug: ${DEBUG}"

    case "${MODE}" in
        setup)
            setup_bastion
            ;;
        teardown)
            teardown_bastion
            ;;
        *)
            log_error "Invalid mode: ${MODE}. Must be 'setup' or 'teardown'"
            return 1
            ;;
    esac
}

# Disable exit trap for main execution
trap - EXIT

main
exit $?
