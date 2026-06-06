# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
"""Basic tests for action configuration."""

import os
import yaml
from pathlib import Path


def test_action_yaml_exists():
    """Test that action.yaml exists."""
    action_path = Path(__file__).parent.parent / "action.yaml"
    assert action_path.exists(), "action.yaml file should exist"


def test_action_yaml_valid():
    """Test that action.yaml is valid YAML."""
    action_path = Path(__file__).parent.parent / "action.yaml"
    with open(action_path, "r") as f:
        data = yaml.safe_load(f)

    assert isinstance(data, dict), "action.yaml should contain a dictionary"
    assert "name" in data, "action.yaml should have a name field"
    assert "description" in data, "action.yaml should have a description field"
    assert "inputs" in data, "action.yaml should have inputs field"
    assert "runs" in data, "action.yaml should have runs field"


def test_action_has_required_inputs():
    """Test that action.yaml has required inputs."""
    action_path = Path(__file__).parent.parent / "action.yaml"
    with open(action_path, "r") as f:
        data = yaml.safe_load(f)

    inputs = data.get("inputs", {})

    # Check for essential inputs
    required_inputs = [
        "operation",
        "openstack_auth_url",
        "openstack_project_id",
        "openstack_region",
    ]

    for input_name in required_inputs:
        assert input_name in inputs, f"action.yaml should have {input_name} input"


def test_scripts_directory_exists():
    """Test that scripts directory exists."""
    scripts_path = Path(__file__).parent.parent / "scripts"
    assert scripts_path.exists(), "scripts directory should exist"
    assert scripts_path.is_dir(), "scripts should be a directory"


def test_essential_scripts_exist():
    """Test that essential scripts exist."""
    scripts_path = Path(__file__).parent.parent / "scripts"

    essential_scripts = [
        "setup-bastion.sh",
        "cleanup-bastion.sh",
        "bastion-manager.sh",
    ]

    for script_name in essential_scripts:
        script_path = scripts_path / script_name
        assert script_path.exists(), f"{script_name} should exist"
        # Check if executable
        assert os.access(script_path, os.X_OK), f"{script_name} should be executable"
