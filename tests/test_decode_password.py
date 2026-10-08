# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
"""Tests for the openstack_password decoding contract."""

import base64
import os
import subprocess
from pathlib import Path
from typing import Any

import pytest
import yaml

ROOT = Path(__file__).parent.parent
SCRIPT = ROOT / "scripts" / "decode-password.sh"


def run_decode(value: str) -> subprocess.CompletedProcess[bytes]:
    """Run the decode script with OS_PASSWORD set to value."""
    env = {**os.environ, "OS_PASSWORD": value}
    return subprocess.run([str(SCRIPT)], env=env, capture_output=True, check=False)


def encode(password: str) -> str:
    """Base64-encode password the way callers are told to."""
    return base64.b64encode(password.encode()).decode()


@pytest.mark.parametrize("password", ["S3cret-Pass!", "hunter22", "pässwörd"])
def test_decodes_base64_password(password: str):
    """A base64-encoded password decodes to the original bytes."""
    result = run_decode(encode(password))

    assert result.returncode == 0, result.stderr
    assert result.stdout == password.encode()


def test_decodes_wrapped_base64_password():
    """Line-wrapped output from base64 tools decodes too."""
    password = "x" * 80
    wrapped = base64.encodebytes(password.encode()).decode()
    assert "\n" in wrapped.rstrip("\n")

    result = run_decode(wrapped)

    assert result.returncode == 0, result.stderr
    assert result.stdout == password.encode()


@pytest.mark.parametrize(
    ("value", "message"),
    [
        # Outside the base64 alphabet: base64 -d rejects it outright
        ("S3cret-Pass!", b"not valid base64"),
        # Valid base64 that decodes to bytes no password can contain
        ("hunter22", b"does not decode to UTF-8 text"),
        ("", b"is empty"),
        # An environment variable cannot carry a NUL, so the decoded
        # password could never reach the OpenStack client intact
        ("YWIAY2Q=", b"contains a NUL byte"),
    ],
)
def test_rejects_value_that_is_not_an_encoded_password(value: str, message: bytes):
    """Fail with an error naming the input, and print nothing."""
    result = run_decode(value)

    assert result.returncode != 0
    assert result.stdout == b""
    assert b"openstack_password" in result.stderr
    assert message in result.stderr


def test_action_decodes_password_only_through_script():
    """Every step handed the password validates it the same way."""
    with open(ROOT / "action.yaml") as f:
        action: dict[str, Any] = yaml.safe_load(f)

    steps: list[dict[str, Any]] = action["runs"]["steps"]
    password_steps = [s for s in steps if "OS_PASSWORD" in s.get("env", {})]

    assert password_steps
    for step in password_steps:
        assert "scripts/decode-password.sh" in step["run"], step["name"]
        assert "base64 -d" not in step["run"], step["name"]


def test_strips_trailing_newlines():
    """An encoded trailing newline, as `echo pw | base64` adds, is dropped."""
    result = run_decode(encode("S3cret-Pass!\n"))

    assert result.returncode == 0, result.stderr
    assert result.stdout == b"S3cret-Pass!"
