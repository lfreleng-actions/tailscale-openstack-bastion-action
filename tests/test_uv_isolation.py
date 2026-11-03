# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
"""Check the OpenStack CLI install syncs against the action's own lock."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).parent.parent

# The flags the 'Install OpenStack CLI' step passes to 'uv sync'.
SYNC_FLAGS = [
    "--no-config",
    "--locked",
    "--only-group",
    "openstack-cli",
    "--no-install-project",
    "--directory",
]


def _install_step_script() -> str:
    """Return the run script of the action's OpenStack CLI install step."""
    with open(ROOT / "action.yaml") as f:
        action = yaml.safe_load(f)
    for step in action["runs"]["steps"]:
        if step.get("name") == "Install OpenStack CLI":
            return step["run"]
    raise AssertionError("action.yaml has no 'Install OpenStack CLI' step")


def test_install_step_uses_locked_sync_flags():
    """The install step passes every flag this module's sync relies on."""
    script = _install_step_script()
    assert '"$UV" sync' in script
    for flag in SYNC_FLAGS:
        assert flag in script, f"install step lacks {flag}"


@pytest.mark.skipif(shutil.which("uv") is None, reason="uv is not on PATH")
def test_sync_ignores_enclosing_caller_workspace(tmp_path: Path):
    """A caller workspace listing the action as a member is not used."""
    caller = tmp_path / "caller"
    action = caller / "vendor" / "action"
    action.mkdir(parents=True)
    (caller / "pyproject.toml").write_text(
        "[project]\n"
        'name = "caller"\n'
        'version = "0.1.0"\n'
        'requires-python = ">=3.10"\n'
        "\n"
        "[tool.uv.workspace]\n"
        'members = ["vendor/*"]\n'
    )
    for name in ("pyproject.toml", "uv.lock"):
        shutil.copy(ROOT / name, action / name)

    env = dict(os.environ)
    env["UV_PROJECT_ENVIRONMENT"] = str(tmp_path / "openstack-cli")
    env["UV_PYTHON_DOWNLOADS"] = "never"
    result = subprocess.run(
        ["uv", "sync", *SYNC_FLAGS, str(action), "--dry-run"],
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    assert "python-openstackclient" in result.stderr
