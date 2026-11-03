# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
"""Check no caller variable can choose the Python the action runs."""

import re
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).parent.parent
STATE = "${{ runner.temp }}/tailscale-openstack-bastion-action"


def _steps() -> list[dict[str, Any]]:
    """Return the action's composite steps."""
    with open(ROOT / "action.yaml") as f:
        action: dict[str, Any] = yaml.safe_load(f)
    return action["runs"]["steps"]


def _step(name: str) -> dict[str, Any]:
    """Return the composite step called name."""
    for step in _steps():
        if step.get("name") == name:
            return step
    raise AssertionError(f"action.yaml has no {name!r} step")


def _commands(script: str) -> list[str]:
    """Return the script's commands, with continuation lines joined."""
    joined = re.sub(r"\\\n\s*", " ", script)
    return [line.strip() for line in joined.splitlines() if line.strip()]


def test_setup_uv_step_is_guarded():
    """The setup-uv step takes the guarded form, exactly."""
    step = _step("Install uv")
    assert step["id"] == "setup-uv"
    assert step["uses"].startswith("astral-sh/setup-uv@")
    assert step["with"] == {
        "version": "0.13.4",
        "working-directory": "${{ github.action_path }}",
        "tool-bin-dir": f"{STATE}/bin",
        "enable-cache": False,
    }
    assert step["env"] == {
        "UV_NO_CONFIG": "1",
        "UV_NO_PROJECT": "1",
        "UV_PYTHON_PREFERENCE": "lookup-disabled",
        "UV_PYTHON_ARCH": "",
        "UV_PYTHON_INSTALL_DIR": f"{STATE}/python",
    }


def test_uv_calls_pin_the_trusted_interpreter():
    """Every uv call runs under env -i or passes an absolute --python."""
    calls = 0
    for step in _steps():
        for command in _commands(step.get("run", "")):
            if command.startswith("#") or "echo " in command:
                continue
            assert not re.search(r"(^|[\s;(|&])uvx?\s", command), command
            if '"$UV"' not in command:
                continue
            calls += 1
            isolated = 'env -i "${clean[@]}" "$UV" ' in command
            assert isolated or '--python "$' in command, command
            for flag in ("--system", "--managed-python ", "--python '"):
                if "python find" not in command:
                    assert flag not in command, command
    assert calls >= 3


def test_openstack_cli_runs_isolated():
    """The installed 'openstack' starts its interpreter with -I."""
    script = _step("Install OpenStack CLI")["run"]
    assert '--python "$PYTHON"' in script
    assert "ln -s" not in script
    assert '-I %q "$@"' in script
    assert "unset PYTHONEXECUTABLE __PYVENV_LAUNCHER__" in script
    env = _step("Install OpenStack CLI")["env"]
    assert env["PYTHON"] == "${{ steps.python.outputs.path }}"
    assert env["UV"] == "${{ steps.setup-uv.outputs.uv-path }}"
