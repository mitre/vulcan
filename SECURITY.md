---
title: Security Policy
description: Security vulnerability reporting and policies for Vulcan
layout: doc
sidebar: true
---

# Security Policy

## Reporting Security Issues

The MITRE SAF team takes security seriously. If you discover a security vulnerability in Vulcan, please report it responsibly.

### Contact Information

- **Email**: [saf-security@mitre.org](mailto:saf-security@mitre.org)
- **GitHub**: Use the [Security tab](https://github.com/mitre/vulcan/security) to report vulnerabilities privately

### What to Include

When reporting security issues, please provide:

1. **Description** of the vulnerability
2. **Steps to reproduce** the issue
3. **Potential impact** assessment
4. **Suggested fix** (if you have one)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 7 days
- **Fix Timeline**: Varies by severity

## Security Best Practices

### For Users

- **Keep Updated**: Use the latest version of Vulcan
- **Secure Credentials**: Never commit passwords or SSH keys to version control
- **Use OIDC/LDAP**: Prefer enterprise authentication over local accounts
- **Network Security**: Use HTTPS and secure networks when accessing Vulcan

### For Contributors

- **Dependency Scanning**: Run `bundle audit` before submitting PRs
- **Credential Handling**: Never log or expose credentials in code
- **Input Validation**: Sanitize all user inputs
- **Test Security**: Include security tests for new features

## Supported Versions

| Version | Supported |
|---------|-----------|
| 2.2.x   | ✅ Yes    |
| 2.1.x   | ✅ Yes    |
| < 2.1   | ❌ No     |

## Security Testing

Vulcan includes comprehensive security testing:

```bash
# Run full test suite
bundle exec rspec

# Check for vulnerable dependencies
bundle exec bundle-audit check

# Scan for potential security issues
bundle exec brakeman
```

## Known Security Considerations

### Authentication
- Vulcan supports multiple authentication methods (OIDC, LDAP, local)
- Use enterprise authentication (OIDC/LDAP) in production
- Enforce strong password policies for local accounts

### Data Protection
- Sensitive data is encrypted using symmetric encryption
- Database credentials should be properly secured
- Use SSL/TLS for all external connections

### Container Security
- Docker images run as non-root user
- Keep base images updated
- Scan images for vulnerabilities regularly