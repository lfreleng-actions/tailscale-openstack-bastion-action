# Development Guide

Guide for developers working on the Packer GitHub Action.

## Development Setup

### Prerequisites

```bash
# Required tools
- Python 3.11+
- Git
- pre-commit
- actionlint
- shellcheck
- yamllint
```

### Initial Setup

```bash
# Clone repository
git clone https://github.com/lfit/releng-packer-action.git
cd releng-packer-action

# Install Python dependencies
pip install -r requirements-dev.txt

# Install pre-commit hooks
pre-commit install

# Run initial checks
pre-commit run --all-files
```

---

## Project Structure

```
releng-packer-action/
├── .github/
│   └── workflows/
│       ├── pre-commit.yaml              # Code quality checks
│       ├── test-action-validate.yaml    # Validation tests
│       └── test-tailscale-setup-build-minimal.yaml  # Integration tests
├── action.yaml                          # Main action definition
├── examples/
│   └── workflows/
│       ├── gerrit-packer-verify.yaml    # Example verify workflow
│       └── gerrit-packer-merge.yaml     # Example merge/build workflow
├── scripts/
│   ├── setup-bastion.sh                 # Bastion host setup
│   ├── validate-packer.sh               # Packer validation
│   └── build-packer.sh                  # Packer build execution
├── templates/
│   └── bastion-cloud-init.yaml          # Bastion cloud-init template
├── tests/                               # Python tests
│   ├── test_action.py
│   └── test_scripts.py
├── docs/
│   ├── TAILSCALE_SETUP.md               # Tailscale configuration
│   └── examples/                        # Usage examples
├── pyproject.toml                       # Python project config
├── .pre-commit-config.yaml              # Pre-commit configuration
└── README.md                            # Main documentation
```

---

## Testing

### Pre-commit Hooks

Automatically run on every commit:

```bash
# Run all hooks
pre-commit run --all-files

# Run specific hook
pre-commit run actionlint --all-files
pre-commit run shellcheck --all-files
pre-commit run check-yaml --all-files
```

### Manual Testing

#### Test Action Validation

```bash
# Trigger validation workflow
gh workflow run test-action-validate.yaml

# Watch progress
gh run watch
```

#### Test Bastion Setup

```bash
# Trigger integration test
gh workflow run test-tailscale-setup-build-minimal.yaml \
  -f debug_mode=true

# View logs
gh run view --log
```

#### Test with Example Workflows

```bash
# Test verify workflow
gh workflow run gerrit-packer-verify.yaml \
  -f GERRIT_CHANGE_URL="https://gerrit.example.com/12345" \
  -f GERRIT_PATCHSET_REVISION="abc123"

# Test merge workflow (manual trigger)
gh workflow run gerrit-packer-merge.yaml \
  -f build_trigger="manual"
```

### Python Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=scripts --cov-report=html

# Run specific test
pytest tests/test_action.py::test_validate_inputs
```

---

## Code Style

### Shell Scripts

- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `shellcheck` for linting
- Add error handling with `set -euo pipefail`
- Use descriptive variable names in UPPER_CASE

Example:

```bash
#!/bin/bash
set -euo pipefail

PACKER_TEMPLATE="${1:-}"
PACKER_VARS="${2:-}"

if [[ -z "$PACKER_TEMPLATE" ]]; then
  echo "❌ Error: PACKER_TEMPLATE required" >&2
  exit 1
fi
```

### YAML Files

- 2-space indentation
- Use `yamllint` for validation
- Quote strings with special characters
- Use explicit anchors/aliases sparingly

### Python Code

- Follow PEP 8
- Type hints required
- Docstrings for all functions
- Use `black` for formatting
- Use `ruff` for linting

---

## Adding Features

### Adding New Action Inputs

1. Update `action.yaml`:

```yaml
inputs:
    new_feature:
        description: "Description of new feature"
        required: false
        default: "default-value"
```

1. Update scripts to use input:

```bash
# In scripts/build-packer.sh
NEW_FEATURE="${INPUT_NEW_FEATURE:-}"
```

1. Update documentation:

    - README.md - Add to inputs table
    - examples/ - Show usage example

2. Add tests:

```python
def test_new_feature():
    # Test implementation
    pass
```

### Adding New Scripts

1. Create script in `scripts/`:

```bash
#!/bin/bash
set -euo pipefail

# Script implementation
```

1. Make executable:

```bash
chmod +x scripts/new-script.sh
```

1. Add to `action.yaml`:

```yaml
- name: Run New Script
  shell: bash
  run: |
      bash scripts/new-script.sh "${{ inputs.parameter }}"
```

1. Add tests and documentation

---

## Workflow Development

### Testing Workflow Changes

#### Local ActionLint

```bash
# Install actionlint
brew install actionlint  # macOS
# or
go install github.com/rhysd/actionlint/cmd/actionlint@latest

# Run on specific file
actionlint .github/workflows/test-action-validate.yaml

# Run on all workflows
actionlint .github/workflows/*.yaml
```

#### Act (Local GitHub Actions)

```bash
# Install act
brew install act  # macOS

# Run workflow locally
act -W .github/workflows/test-action-validate.yaml

# With secrets
act -W .github/workflows/test-action-validate.yaml \
  --secret-file .secrets
```

### Debugging Workflows

Enable debug logging:

```yaml
env:
    ACTIONS_STEP_DEBUG: true
    ACTIONS_RUNNER_DEBUG: true
```

Or add to workflow run:

```bash
gh workflow run test-action-validate.yaml \
  -f debug_mode=true
```

---

## Release Process

### Version Tagging

```bash
# Create new version tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Update major version tag
git tag -fa v1 -m "Update v1 to v1.0.0"
git push origin v1 --force
```

### Release Checklist

- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in relevant files
- [ ] Git tag created
- [ ] GitHub release created
- [ ] Example workflows tested

### Creating GitHub Release

```bash
# Using GitHub CLI
gh release create v1.0.0 \
  --title "v1.0.0" \
  --notes "Release notes here"
```

---

## CI/CD Pipeline

### Pre-commit Workflow

Runs on every push and PR:

- YAML validation
- Shell script linting
- Action metadata validation
- Markdown linting
- Python linting

### Test Workflows

#### test-action-validate.yaml

- Tests Packer validation mode
- Uses syntax-only validation
- No bastion required
- Fast feedback (~2 minutes)

#### test-tailscale-setup-build-minimal.yaml

- Tests full integration
- Creates bastion host
- Tests Tailscale connectivity
- Tests Packer build
- Full cleanup
- Longer runtime (~10 minutes)

---

## Common Development Tasks

### Update Action Dependencies

```bash
# Update pre-commit hooks
pre-commit autoupdate

# Update Python dependencies
pip-compile --upgrade requirements-dev.in

# Update action versions
# Edit .github/workflows/*.yaml
# Update commit SHAs for pinned actions
```

### Add New Example

1. Create example in `examples/workflows/`
2. Test with actual workflow run
3. Document in examples/README.md
4. Link from main README.md

### Fix Security Issues

```bash
# Run security scanners
pre-commit run check-added-large-files --all-files
pre-commit run check-merge-conflict --all-files
pre-commit run detect-private-key --all-files

# Update vulnerable dependencies
pip-audit
```

---

## Troubleshooting Development Issues

### Pre-commit Hooks Failing

```bash
# Clear cache and retry
pre-commit clean
pre-commit run --all-files

# Skip specific hook temporarily
SKIP=shellcheck git commit -m "message"
```

### Action Not Using Latest Changes

```bash
# Workflows reference action by branch/tag
# For testing, use branch reference:
uses: lfit/releng-packer-action@feature-branch

# Ensure changes are pushed
git push origin feature-branch
```

### Bastion Not Starting

```bash
# Check cloud-init template syntax
cloud-init schema --config-file templates/bastion-cloud-init.yaml

# Validate with actual cloud-init
cloud-init devel schema -c templates/bastion-cloud-init.yaml --annotate
```

---

## Contributing

### Pull Request Process

1. Fork repository
2. Create feature branch from `main`
3. Make changes following code style
4. Add/update tests
5. Run pre-commit hooks
6. Update documentation
7. Submit PR with description

### PR Requirements

- [ ] All CI checks passing
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Commit messages follow conventions
- [ ] DCO sign-off included

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>

Signed-off-by: Your Name <your.email@example.com>
```

**Types:** feat, fix, docs, style, refactor, test, chore

**Example:**

```
feat(action): Add OAuth client support for Tailscale

- Add tailscale_oauth_client_id input
- Add tailscale_oauth_secret input
- Update bastion setup to use OAuth
- Add fallback to auth key method
- Update documentation

Signed-off-by: Anil Belur <askb23@gmail.com>
```

---

## Getting Help

- **Documentation:** See `docs/` directory
- **Issues:** [GitHub Issues](https://github.com/lfit/releng-packer-action/issues)
- **Discussions:** [GitHub Discussions](https://github.com/lfit/releng-packer-action/discussions)
- **Slack:** #releng channel (for LF projects)

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Composite Actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [Action Metadata Syntax](https://docs.github.com/en/actions/creating-actions/metadata-syntax-for-github-actions)
- [Packer Documentation](https://developer.hashicorp.com/packer)
- [Tailscale API](https://tailscale.com/kb/1101/api)
- [OpenStack CLI](https://docs.openstack.org/python-openstackclient/)
