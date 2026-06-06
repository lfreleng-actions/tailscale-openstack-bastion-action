#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
#
# Generate ephemeral Tailscale auth key from OAuth credentials

set -euo pipefail

# Script variables
TAILSCALE_OAUTH_CLIENT_ID="${TAILSCALE_OAUTH_CLIENT_ID:?Error: TAILSCALE_OAUTH_CLIENT_ID not set}"
TAILSCALE_OAUTH_SECRET="${TAILSCALE_OAUTH_SECRET:?Error: TAILSCALE_OAUTH_SECRET not set}"
TAILSCALE_TAGS="${TAILSCALE_TAGS:-tag:ci}"
KEY_EXPIRY="${KEY_EXPIRY:-3600}" # 1 hour default
EPHEMERAL="${EPHEMERAL:-true}"
PREAUTH="${PREAUTH:-true}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    echo "[ERROR] $*" >&2
}

# Get OAuth token from Tailscale
get_oauth_token() {
    log "Getting OAuth token from Tailscale..."

    local response
    if ! response=$(curl -s -f -X POST \
        "https://api.tailscale.com/api/v2/oauth/token" \
        -u "${TAILSCALE_OAUTH_CLIENT_ID}:${TAILSCALE_OAUTH_SECRET}" \
        -d "grant_type=client_credentials" \
        -d "scope=auth_keys" 2>&1); then
        error "Failed to get OAuth token"
        error "Response: ${response}"
        return 1
    fi

    local access_token
    access_token=$(echo "${response}" | jq -r '.access_token')

    if [[ -z "${access_token}" || "${access_token}" == "null" ]]; then
        error "Failed to extract access token from response"
        error "Response: ${response}"
        return 1
    fi

    echo "${access_token}"
}

# Get tailnet from OAuth credentials
# The tailnet can be extracted from the client ID (format: <client-id>@<tailnet>)
# Or we can use '-' which is a special value that means "the tailnet the auth is for"
get_tailnet() {
    local access_token="$1"

    log "Getting tailnet information..."

    # Try to get tailnet from API first
    local response
    if response=$(curl -s -X GET \
        "https://api.tailscale.com/api/v2/tailnet" \
        -H "Authorization: Bearer ${access_token}" 2>&1); then

        local tailnet
        tailnet=$(echo "${response}" | jq -r '.[0]' 2>/dev/null || echo "")

        if [[ -n "${tailnet}" && "${tailnet}" != "null" ]]; then
            log "Found tailnet: ${tailnet}"
            echo "${tailnet}"
            return 0
        fi
    fi

    # Fallback: Use '-' which represents the tailnet associated with the OAuth client
    log "Using '-' (OAuth client's tailnet) as fallback"
    echo "-"
}

# Generate ephemeral auth key
generate_auth_key() {
    local access_token="$1"
    local tailnet="$2"

    log "Generating ephemeral auth key..."
    log "  Tailnet: ${tailnet}"
    log "  Tags: ${TAILSCALE_TAGS}"
    log "  Expiry: ${KEY_EXPIRY}s"
    log "  Ephemeral: ${EPHEMERAL}"
    log "  Preauth: ${PREAUTH}"

    # Build JSON request
    local tags_json
    tags_json=$(echo "${TAILSCALE_TAGS}" | tr ',' '\n' | jq -R . | jq -s .)

    local request_body
    request_body=$(jq -n \
        --argjson capabilities '{"devices": {"create": {"reusable": true, "ephemeral": '"${EPHEMERAL}"', "preauthorized": '"${PREAUTH}"', "tags": '"${tags_json}"'}}}' \
        --arg expiry "${KEY_EXPIRY}" \
        '{
            capabilities: $capabilities,
            expirySeconds: ($expiry | tonumber)
        }')

    log "Request body: ${request_body}"

    local response
    if ! response=$(curl -s -f -X POST \
        "https://api.tailscale.com/api/v2/tailnet/${tailnet}/keys" \
        -H "Authorization: Bearer ${access_token}" \
        -H "Content-Type: application/json" \
        -d "${request_body}" 2>&1); then
        error "Failed to generate auth key"
        error "Response: ${response}"
        return 1
    fi

    local auth_key
    auth_key=$(echo "${response}" | jq -r '.key')

    if [[ -z "${auth_key}" || "${auth_key}" == "null" ]]; then
        error "Failed to extract auth key from response"
        error "Response: ${response}"
        return 1
    fi

    log "✅ Successfully generated ephemeral auth key"
    echo "${auth_key}"
}

# Main execution
main() {
    log "=== Generating Ephemeral Tailscale Auth Key ==="

    # Validate dependencies
    if ! command -v curl &>/dev/null; then
        error "curl is required but not installed"
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        error "jq is required but not installed"
        exit 1
    fi

    # Get OAuth token
    local access_token
    if ! access_token=$(get_oauth_token); then
        error "Failed to get OAuth token"
        exit 1
    fi

    # Get tailnet
    local tailnet
    if ! tailnet=$(get_tailnet "${access_token}"); then
        error "Failed to get tailnet"
        exit 1
    fi

    # Generate auth key
    local auth_key
    if ! auth_key=$(generate_auth_key "${access_token}" "${tailnet}"); then
        error "Failed to generate auth key"
        exit 1
    fi

    # Output the key (this will be captured by the caller)
    echo "${auth_key}"

    log "=== Key Generation Complete ==="
}

# Run main function
main "$@"
