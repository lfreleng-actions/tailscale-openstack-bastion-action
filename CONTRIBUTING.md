<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Contributing to OpenStack Bastion Action

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Coding Standards](#coding-standards)
- [License](#license)

## Code of Conduct

This project follows the [Linux Foundation Code of Conduct](https://www.linuxfoundation.org/code-of-conduct/). By participating, you are expected to uphold this code.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR-USERNAME/tailscale-openstack-bastion-action.git`
3. Add upstream remote: `git remote add upstream https://github.com/askb/tailscale-openstack-bastion-action.git`
4. Create a feature branch: `git checkout -b feature/your-feature-name`

## Development Setup

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for detailed setup instructions.

### Quick Setup

```bash
# Install Python dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements-dev.txt

# Install pre-commit hooks
pre-commit install
pre-commit install --hook-type commit-msg

# Run tests
pytest tests/
```

### Pre-commit Hooks

This project uses pre-commit hooks to ensure code quality:

- **Trailing whitespace removal**
- **YAML validation**
- **Shell script linting (ShellCheck)**
- **Spell checking (Codespell)**
- **REUSE compliance**

Run manually:

```bash
pre-commit run --all-files
```

## Making Changes

### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `test/description` - Test improvements
- `chore/description` - Maintenance tasks

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): brief description

Detailed explanation of changes.

Signed-off-by: Your Name <your.email@example.com>
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `test`: Tests
- `chore`: Maintenance
- `refactor`: Code refactoring
- `ci`: CI/CD changes

**Examples:**

```
feat(oauth): add support for custom OAuth endpoints

fix(bastion): handle network disconnect gracefully

docs(setup): update Tailscale configuration guide
```

**Sign your commits:**

```bash
git commit -s -m "feat: your commit message"
```

## Testing

### Unit Tests

```bash
pytest tests/ -v
```

### Integration Tests

Integration tests run in GitHub Actions using actual OpenStack and Tailscale infrastructure.

**Local testing** (requires credentials):

```bash
# Test with OAuth ephemeral keys
.github/workflows/test-oauth-ephemeral.yaml

# Test with legacy auth keys
.github/workflows/test-authkey.yaml
```

### Test Coverage

```bash
pytest tests/ --cov=. --cov-report=html
open htmlcov/index.html
```

## Submitting Changes

1. **Sync with upstream:**

    ```bash
    git fetch upstream
    git rebase upstream/main
    ```

2. **Run all checks:**

    ```bash
    pre-commit run --all-files
    pytest tests/
    ```

3. **Push to your fork:**

    ```bash
    git push origin feature/your-feature-name
    ```

4. **Create Pull Request:**
    - Use a descriptive title following conventional commits
    - Reference any related issues
    - Provide clear description of changes
    - Include test results if applicable

### Pull Request Checklist

- [ ] Code follows project style guidelines
- [ ] All tests pass
- [ ] Documentation updated (if needed)
- [ ] Commit messages follow conventional commits
- [ ] Commits are signed (`-s`)
- [ ] Pre-commit hooks pass
- [ ] REUSE compliance maintained

## Coding Standards

### Shell Scripts

- Use ShellCheck for linting
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Add error handling (`set -euo pipefail`)
- Use meaningful variable names
- Add comments for complex logic

### Python Code

- Follow PEP 8 style guide
- Use type hints where applicable
- Add docstrings for functions/classes
- Keep functions focused and small

### YAML Files

- Use 2-space indentation
- Follow yamllint rules
- Add comments for complex configurations

### Documentation

- Use Markdown for all documentation
- Follow structure in existing docs
- Include code examples
- Keep line length reasonable (80-100 chars)

## REUSE Compliance

All files must have SPDX headers:

**Shell/Python:**

```bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation
```

**YAML/Markdown:**

```yaml
<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->
```

Check compliance:

```bash
reuse lint
```

## Release Process

Releases are automated via GitHub Actions:

1. Merge changes to `main`
2. Create tag: `git tag -a v1.x.x -m "Release v1.x.x"`
3. Push tag: `git push origin v1.x.x`
4. GitHub Actions creates release automatically

## Getting Help

- **Documentation:** Check [docs/](docs/) directory
- **Issues:** Search [existing issues](https://github.com/askb/tailscale-openstack-bastion-action/issues)
- **Discussions:** Use GitHub Discussions for questions

## Recognition

Contributors are recognized in:

- Release notes (auto-generated)
- README.md contributors section
- Git commit history

Thank you for contributing! 🎉
