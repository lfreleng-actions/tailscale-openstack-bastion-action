<!--
SPDX-License-Identifier: Apache-2.0
SPDX-FileCopyrightText: 2025 The Linux Foundation
-->

# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

### Preferred Method: Private Security Advisory

1. Go to the [Security Advisories](https://github.com/askb/tailscale-openstack-bastion-action/security/advisories) page
2. Click "Report a vulnerability"
3. Provide detailed information about the vulnerability

### Alternative: Email

Send vulnerability reports to: **<security@linuxfoundation.org>**

Include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Response Timeline

- **Initial Response:** Within 48 hours
- **Status Update:** Within 7 days
- **Fix Timeline:** Varies by severity

## Severity Levels

### Critical

- Remote code execution
- Authentication bypass
- Privilege escalation
- **Response:** Immediate (24-48 hours)

### High

- Information disclosure of sensitive data
- Denial of service
- **Response:** Within 7 days

### Medium

- Minor information disclosure
- Security misconfiguration
- **Response:** Within 14 days

### Low

- Best practice violations
- **Response:** Next regular release

## Security Best Practices

### For Users

1. **Use OAuth Ephemeral Keys** (recommended)

    - Automatic key rotation
    - Short-lived credentials
    - No manual key management

2. **Rotate Legacy Auth Keys** (if used)

    - Rotate every 90 days maximum
    - Use GitHub Secrets for storage
    - Never commit keys to repositories

3. **Limit Tailscale Permissions**

    - Use appropriate tags (`tag:bastion`)
    - Configure restrictive ACLs
    - Review access regularly

4. **Secure OpenStack Credentials**

    - Store in GitHub Secrets
    - Use application credentials (not user passwords)
    - Limit credential scope

5. **Monitor Bastion Activity**
    - Review GitHub Actions logs
    - Monitor Tailscale admin console
    - Check OpenStack audit logs

### For Developers

1. **Pin External Actions**

    - Use commit SHA pins, not tags
    - Regularly update pinned versions
    - Review changes before updating

2. **Validate Inputs**

    - Never trust user input
    - Sanitize all inputs
    - Use input validation patterns

3. **Handle Secrets Safely**

    - Never log secrets
    - Use GitHub's secret masking
    - Clear secrets after use

4. **Follow Least Privilege**
    - Request minimum required permissions
    - Scope credentials appropriately
    - Use read-only when possible

## Known Security Considerations

### Tailscale Integration

- **Risk:** Compromised Tailscale credentials could allow network access
- **Mitigation:**
  - Use OAuth ephemeral keys with 1-hour expiry
  - Tag-based ACL restrictions
  - Automatic cleanup on bastion teardown

### OpenStack Credentials

- **Risk:** Leaked OpenStack credentials could allow resource creation
- **Mitigation:**
  - Store in GitHub Secrets only
  - Use application credentials with limited scope
  - Monitor OpenStack activity

### SSH Access

- **Risk:** Bastion could be used as attack vector
- **Mitigation:**
  - Ephemeral bastions (destroyed after use)
  - Tailscale network isolation
  - No public IP exposure

### Cloud-Init Scripts

- **Risk:** Malicious cloud-init could compromise bastion
- **Mitigation:**
  - Template-based cloud-init generation
  - Input validation and sanitization
  - No dynamic code execution

## Security Updates

Security updates are released:

- **Critical:** Immediately upon fix
- **High:** Within 7 days
- **Medium/Low:** Next regular release

Updates are announced via:

- GitHub Security Advisories
- Release notes
- README.md

## Disclosure Policy

We follow responsible disclosure:

1. **Private Disclosure:** Reported vulnerabilities are kept confidential
2. **Coordinated Fix:** Work with reporter to develop fix
3. **Public Disclosure:** After fix is released (or 90 days, whichever comes first)
4. **Credit:** Reporter credited in security advisory (if desired)

## Security Features

### Current Security Measures

- ✅ OAuth credential management
- ✅ Ephemeral auth keys with expiry
- ✅ Automatic bastion cleanup
- ✅ Network isolation via Tailscale
- ✅ Input validation and sanitization
- ✅ Secret masking in logs
- ✅ REUSE compliance for licensing
- ✅ SHA-pinned external dependencies (some workflows)

### Planned Enhancements

- [ ] Full SHA pinning of all external actions
- [ ] Automated security scanning in CI
- [ ] Dependency vulnerability scanning
- [ ] SBOM (Software Bill of Materials) generation

## Compliance

This project follows:

- [OpenSSF Best Practices](https://bestpractices.coreinfrastructure.org/)
- [REUSE Specification](https://reuse.software/)
- Linux Foundation security guidelines

## Contact

For security questions: <security@linuxfoundation.org>
For general questions: Use GitHub Discussions

---

**Last Updated:** 2025-10-20
**Security Policy Version:** 1.0
