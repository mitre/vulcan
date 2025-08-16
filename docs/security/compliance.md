# Security Compliance and Control Responses

This document provides Vulcan's security control implementation responses for NIST SP 800-53 Revision 5 controls and their associated Application Security & Development STIG requirements.

## Overview

Vulcan Server implements security controls in accordance with NIST SP 800-53 Rev 5 and the Application Security and Development STIG. This document details how Vulcan addresses each control requirement and provides guidance for proper configuration.

## Implementation Philosophy

Vulcan's security implementation follows these principles:

1. **Defense in Depth**: Multiple layers of security controls
2. **Least Privilege**: Minimal permissions by default
3. **External Integration**: Leverages organizational authentication and logging systems
4. **Audit Trail**: Comprehensive logging of all security-relevant events
5. **Role-Based Access Control**: Granular permission management

## Control Categories

### Access Control (AC)

#### Account Management (AC-02)

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| AC-02 f | Account management process | Vulcan provides user management interface for administrators to provision/deprovision accounts per organizational policy |
| AC-02(01) | Automated account management | Integrate with organizational LDAP/OIDC/OAuth for automated account management |
| AC-02(02) | Temporary account removal | Leverage organizational identity provider for temporary account management |
| AC-02(03) | Account inactivity | Organizational identity provider handles account inactivity policies |
| AC-02(04) | Audit account actions | Account events logged when using local accounts; external providers handle their own auditing |

**Configuration**: Use external authentication providers (LDAP, OIDC, GitHub OAuth) for automated account management. Local accounts should only be used for administration and troubleshooting.

#### Authorization and Access Enforcement (AC-03, AC-04)

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| AC-03 | Logical access control | Role-based access control for users, administrators, and project members |
| AC-03(04) | Discretionary access control | Project-level permissions with owner/editor/viewer roles |
| AC-04 | Information flow control | RBAC enforced at GUI and API levels |

#### Privilege Management (AC-06)

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| AC-06(04) | Network segmentation | Supports tiered deployment with separate database server |
| AC-06(08) | Minimal privileges | Application runs with non-root user; database uses limited account |
| AC-06(09) | Audit privileged functions | All administrative actions logged with user ID and timestamp |
| AC-06(10) | Prevent privilege escalation | RBAC prevents non-privileged users from accessing admin functions |

#### Unsuccessful Login Attempts (AC-07)

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| AC-07 a | Login attempt limits | Configure through external identity provider |
| AC-07 b | Account unlock process | Managed through organizational identity provider |

**Configuration**: Set login policies in your LDAP/OIDC provider. For local accounts, implement organizational unlock procedures.

#### System Use Notification (AC-08)

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| AC-08 a,b,c | Organization banner | Configure via `VULCAN_WELCOME_TEXT` environment variable |

**Configuration**:
```bash
export VULCAN_WELCOME_TEXT="AUTHORIZED USE ONLY. By accessing this system, you agree to comply with all organizational policies..."
```

#### Session Management (AC-10, AC-12)

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| AC-10 | Session limits | Under development (Issue #634) |
| AC-12 | Session termination | Configure via `VULCAN_SESSION_TIMEOUT` environment variable |
| AC-12(01) | User logoff | Log Out button provided in interface |
| AC-12(02) | Logoff message | Under development (Issue #635) |

**Configuration**:
```bash
# Set 10-minute timeout for compliance
export VULCAN_SESSION_TIMEOUT=10
```

#### Remote Access (AC-17)

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| AC-17(02) | Encryption for remote access | Deploy behind TLS-terminating reverse proxy |

**Configuration**: Always deploy Vulcan behind HTTPS using nginx, Apache, or cloud load balancer with valid TLS certificates.

### Audit and Accountability (AU)

#### Audit Content (AU-03)

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| AU-03 a | Log events | Application startup/shutdown, data access, data changes logged |
| AU-03 b | Timestamps | Date/time recorded for all events |
| AU-03 c | Event source | URI paths map to application modules |
| AU-03 d | Unique identifier | Configure centralized logging to add application identifier |
| AU-03 e | Event outcome | Success/failure status logged |
| AU-03 f | User identity | User ID logged with each action |

#### Audit Storage and Protection (AU-04, AU-09)

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| AU-04(01) | Off-load audit records | Logs to stdout for collection by centralized system |
| AU-09 | Protect audit information | Integrate with organizational log management system |
| AU-09(02) | Backup audit records | Organizational log system handles backup |
| AU-09(03) | Cryptographic protection | Organizational log system provides integrity protection |

**Configuration**: 
- Application logs to stdout
- PostgreSQL can use pgaudit extension for database auditing
- Forward logs to organizational SIEM/log management system

#### Audit Analysis and Reporting (AU-06, AU-07)

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| AU-06(04) | Centralized review | Logs designed for centralized collection and analysis |
| AU-07 a | Reduction and reporting | Leverage organizational log analysis tools |
| AU-07 b | Original content preservation | Logs are append-only, no modification capability |

### Identification and Authentication (IA)

#### Authentication Management

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| IA-02 | Unique identification | Each user has unique account ID |
| IA-02(01) | Multifactor authentication | Supported via OIDC/SAML providers |
| IA-02(12) | PIV/CAC authentication | Supported via configured OIDC provider |
| IA-05 | Authenticator management | Leverages external provider policies |

**Configuration Options**:
- Local authentication with email/password
- LDAP/Active Directory integration
- OIDC/SAML (supports MFA, PIV/CAC)
- GitHub OAuth

### System and Communications Protection (SC)

#### Transmission Protection (SC-08, SC-13)

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| SC-08 | Transmission confidentiality | Deploy with TLS reverse proxy |
| SC-13 | Cryptographic protection | TLS 1.2+ with strong ciphers |
| SC-23 | Session authenticity | Rails CSRF tokens protect session integrity |

**Configuration**: Configure reverse proxy with:
- TLS 1.2 minimum
- Strong cipher suites only
- Valid certificates from trusted CA
- HSTS headers enabled

### System and Information Integrity (SI)

#### Input Validation (SI-10)

| Control | Requirement | Vulcan Implementation |
|---------|-------------|----------------------|
| SI-10 | Input validation | Rails strong parameters, XSS protection |
| SI-11 | Error handling | Generic error messages to users, detailed logs for admins |

## Configuration Best Practices

### Essential Security Configuration

```bash
# Session Management
export VULCAN_SESSION_TIMEOUT=10  # 10 minutes for compliance

# Authentication
export VULCAN_ENABLE_OIDC=true
export VULCAN_OIDC_ISSUER_URL=https://your-idp.example.com
export VULCAN_OIDC_CLIENT_ID=vulcan
export VULCAN_OIDC_CLIENT_SECRET=<secure-secret>

# Welcome Banner
export VULCAN_WELCOME_TEXT="AUTHORIZED USE ONLY. This system is subject to monitoring."

# Application Security
export RAILS_ENV=production
export RAILS_FORCE_SSL=true
export SECRET_KEY_BASE=<generate-with-rails-secret>

# Logging
export RAILS_LOG_TO_STDOUT=true
export RAILS_LOG_LEVEL=info
```

### Database Security

```sql
-- Create limited database user
CREATE USER vulcan_app WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE vulcan_production TO vulcan_app;
GRANT USAGE ON SCHEMA public TO vulcan_app;
GRANT CREATE ON SCHEMA public TO vulcan_app;

-- Enable pgaudit for compliance logging
CREATE EXTENSION IF NOT EXISTS pgaudit;
```

### Deployment Security

1. **Network Segmentation**
   - Deploy application tier separate from database tier
   - Use private networks for inter-tier communication
   - Expose only HTTPS endpoint through load balancer

2. **Reverse Proxy Configuration**
   ```nginx
   # Strong TLS configuration
   ssl_protocols TLSv1.2 TLSv1.3;
   ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
   ssl_prefer_server_ciphers off;
   
   # Security headers
   add_header Strict-Transport-Security "max-age=63072000" always;
   add_header X-Frame-Options "DENY" always;
   add_header X-Content-Type-Options "nosniff" always;
   ```

3. **Container Security**
   ```dockerfile
   # Run as non-root user
   USER app
   
   # Minimal attack surface
   RUN apt-get remove --purge -y $BUILD_PACKAGES
   ```

## Compliance Status

### Fully Compliant Controls

- Access Control (AC-02, AC-03, AC-04, AC-06)
- Audit Generation (AU-03, AU-12)
- Session Management (AC-12 partial)
- Authentication (IA-02, IA-05)
- Transmission Protection (SC-08, SC-13)

### In Development

- Session Limits (AC-10) - Issue #634
- Logoff Confirmation (AC-12(02)) - Issue #635

### Requires External Integration

- Account lifecycle management (via LDAP/OIDC)
- Multifactor authentication (via OIDC provider)
- Centralized logging and analysis
- Certificate management

## Audit Configuration

### Application Logging

Vulcan logs the following security-relevant events:
- Authentication attempts (success/failure)
- Authorization decisions
- Data access and modifications
- Administrative actions
- Session management events
- System errors and exceptions

### Database Auditing

Enable PostgreSQL audit logging:

```sql
-- Install pgaudit
CREATE EXTENSION pgaudit;

-- Configure audit logging
ALTER SYSTEM SET pgaudit.log = 'ALL';
ALTER SYSTEM SET pgaudit.log_catalog = off;
ALTER SYSTEM SET pgaudit.log_parameter = on;
ALTER SYSTEM SET pgaudit.log_statement_once = on;

-- Reload configuration
SELECT pg_reload_conf();
```

### Log Format

Logs are structured for easy parsing:
```
[timestamp] [level] [user_id] [session_id] [ip_address] [method] [path] [status] [message]
```

## Monitoring and Alerting

### Key Security Metrics

Monitor these events for security incidents:
- Failed authentication attempts > 5 in 15 minutes
- Privilege escalation attempts
- Unauthorized data access attempts
- Mass data exports
- Configuration changes
- Account creation/deletion

### Integration with SIEM

Forward logs to your SIEM with:
```bash
# Syslog forwarding
*.* @@siem.example.com:514

# Or use log shipper (Filebeat, Fluentd, etc.)
```

## Incident Response

### Security Event Procedures

1. **Detection**: Monitor logs for anomalous activity
2. **Containment**: Disable affected accounts
3. **Investigation**: Review audit logs for scope
4. **Remediation**: Apply fixes, rotate credentials
5. **Recovery**: Restore normal operations
6. **Lessons Learned**: Update procedures

### Contact Information

- Security Team: saf-security@mitre.org
- General Support: saf@mitre.org
- GitHub Issues: https://github.com/mitre/vulcan/issues

## Compliance Documentation

### Required Records

Maintain these records for compliance:
- User access reviews (quarterly)
- Audit log reviews (monthly)
- Security incident reports
- Configuration change logs
- Vulnerability scan results

### Audit Support

For compliance audits, provide:
- This security control documentation
- Current configuration settings
- Sample audit logs
- User access lists
- Security incident history

## Updates and Maintenance

This document is maintained as part of the Vulcan project. Updates are made when:
- New security controls are implemented
- Security vulnerabilities are addressed
- Compliance requirements change
- Best practices evolve

Last Updated: October 11, 2024
Version: 2.2.1