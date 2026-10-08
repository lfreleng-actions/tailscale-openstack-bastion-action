#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
#
# Decode the base64-encoded OpenStack password in OS_PASSWORD and print
# it on stdout.
#
# openstack_password is accepted base64 encoded only. Many plain-text
# passwords are also valid base64, so the encoding cannot be guessed;
# instead, reject any value that cannot be an encoded password, with an
# error that names the input rather than a later, opaque auth failure.

set -euo pipefail

error() {
    echo "❌ Error: $*" >&2
}

decode() {
    printf '%s' "${OS_PASSWORD:-}" | base64 -d 2>/dev/null
}

# The checks read the bytes straight from the decoder. Capturing them in
# a variable first would silently drop any NUL and trailing newline.
if ! decode >/dev/null; then
    error "openstack_password is not valid base64."
    error "Pass the base64 encoding of the password, not the password itself."
    exit 1
fi

# An environment variable cannot carry a NUL, so such a password could
# never reach the OpenStack client intact.
if decode | od -An -v -tx1 | grep -w 00 >/dev/null; then
    error "openstack_password decodes to a value that contains a NUL byte"
    exit 1
fi

# Keystone takes the password as a JSON string, so a value that does not
# decode to UTF-8 text can never authenticate. This catches most plain
# text that merely looks like base64.
if ! decode | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; then
    error "openstack_password does not decode to UTF-8 text."
    error "Pass the base64 encoding of the password, not the password itself."
    exit 1
fi

# Capturing drops trailing newlines, deliberately and as the action always
# has: 'echo pw | base64' encodes one the caller never meant to send.
password=$(decode)

if [[ -z "${password}" ]]; then
    error "openstack_password is empty"
    exit 1
fi

printf '%s' "${password}"
