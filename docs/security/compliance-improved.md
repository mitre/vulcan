# Security Compliance Guide

## Overview

Vulcan implements comprehensive security controls aligned with **NIST SP 800-53 Revision 5** and the **Application Security & Development STIG**. This guide provides practical implementation details and configuration requirements for deploying Vulcan in compliance with federal security standards.

## Quick Start Security Configuration

For organizations requiring immediate compliance, apply these essential settings:

```bash
# Core Security Settings
export VULCAN_SESSION_TIMEOUT=10               # Set to 10 minutes (STIG requirement - default is 60)
export VULCAN_WELCOME_TEXT="AUTHORIZED USE ONLY. By accessing this system, you agree to comply with all organizational security policies. All activities are monitored and logged."
export RAILS_FORCE_SSL=true                    # Force HTTPS
export RAILS_ENV=production                    # Production mode
export SECRET_KEY_BASE=$(rails secret)         # Generate secure key

# Authentication (Choose One)
# Option 1: OIDC/SAML
export VULCAN_ENABLE_OIDC=true
export VULCAN_OIDC_ISSUER_URL=https://your-idp.example.com
export VULCAN_OIDC_CLIENT_ID=vulcan
export VULCAN_OIDC_CLIENT_SECRET=<secure-secret>

# Option 2: LDAP
export VULCAN_ENABLE_LDAP=true
export VULCAN_LDAP_HOST=ldap.example.com
export VULCAN_LDAP_PORT=636
export VULCAN_LDAP_BASE="dc=example,dc=com"
```

## Security Architecture

### Defense in Depth Strategy

```
┌─────────────────────────────────────────┐
│         External Users                   │
└─────────────┬───────────────────────────┘
              │ HTTPS/TLS 1.2+
┌─────────────▼───────────────────────────┐
│     Load Balancer / Reverse Proxy       │
│     • TLS Termination                   │
│     • DDoS Protection                   │
│     • Rate Limiting                     │
└─────────────┬───────────────────────────┘
              │ Private Network
┌─────────────▼───────────────────────────┐
│        Application Tier (Vulcan)        │
│     • RBAC Authorization               │
│     • Session Management               │
│     • Input Validation                 │
└─────────────┬───────────────────────────┘
              │ Encrypted Connection
┌─────────────▼───────────────────────────┐
│         Database Tier (PostgreSQL)      │
│     • Encrypted at Rest                │
│     • Audit Logging                    │
│     • Limited Permissions              │
└─────────────────────────────────────────┘
```

## Control Implementation Details

### 🔐 Access Control (AC)

#### Account Management (AC-02)

**What's Required:** Automated account lifecycle management with audit trails

**How Vulcan Implements It:**
- **External Integration:** Leverages your organization's existing identity provider (LDAP, OIDC, GitHub OAuth)
- **Local Account Management:** Admin interface for manual account control when needed
- **Audit Trail:** All account actions logged with timestamp and user ID

**Your Action Items:**
✅ Configure external authentication provider  
✅ Disable local registration in production  
✅ Document account provisioning procedures  

#### Session Management (AC-12)

**What's Required:** Automatic session termination after inactivity

**How Vulcan Implements It:**
- Configurable timeout via `VULCAN_SESSION_TIMEOUT`
- Secure session cookies with Rails session management
- Manual logout capability with session invalidation

**Configuration:**
```bash
# STIG Requirements (value is in minutes)
VULCAN_SESSION_TIMEOUT=10      # Required: 10 min for admin, 15 min for users
                               # Default: 60 minutes if not set
                               # Note: Single timeout for all user types
```

⚠️ **Known Gaps:**
- Session limit per user (Issue #634) - In development
- Logout confirmation message (Issue #635) - In development

#### System Use Notification (AC-08)

**What's Required:** Display approved banner before system access

**How Vulcan Implements It:**
- Customizable banner via `VULCAN_WELCOME_TEXT`
- Displayed on login page before authentication
- Must be acknowledged to proceed

**Example Banner:**
```bash
export VULCAN_WELCOME_TEXT="
╔══════════════════════════════════════════════════════════════╗
║                    AUTHORIZED USE ONLY                       ║
║                                                              ║
║ This U.S. Government system is for authorized use only.     ║
║ By accessing this system, you consent to monitoring and     ║
║ recording of all activities. Unauthorized use is prohibited ║
║ and subject to criminal and civil penalties.                ║
╚══════════════════════════════════════════════════════════════╝
"
```

### 📝 Audit & Accountability (AU)

#### What Gets Logged

| Event Type | Information Captured | Retention |
|------------|---------------------|-----------|
| **Authentication** | User ID, IP, Success/Failure, Timestamp | 90 days minimum |
| **Authorization** | User ID, Resource, Action, Decision | 90 days minimum |
| **Data Changes** | User ID, Before/After Values, Timestamp | 1 year minimum |
| **Admin Actions** | User ID, Action, Target, Result | 1 year minimum |
| **System Events** | Service Start/Stop, Errors, Config Changes | 30 days minimum |

#### Log Format

```json
{
  "timestamp": "2024-10-11T14:30:00Z",
  "level": "INFO",
  "user_id": "user@example.com",
  "session_id": "abc123",
  "ip_address": "192.168.1.100",
  "method": "POST",
  "path": "/api/projects/123",
  "status": 200,
  "message": "Project updated successfully",
  "duration_ms": 145
}
```

#### Database Audit Configuration

Enable comprehensive database auditing with pgAudit:

```sql
-- Install and configure pgAudit extension
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Set audit parameters
ALTER SYSTEM SET pgaudit.log = 'ALL';
ALTER SYSTEM SET pgaudit.log_catalog = off;
ALTER SYSTEM SET pgaudit.log_parameter = on;
ALTER SYSTEM SET pgaudit.log_statement_once = on;
ALTER SYSTEM SET pgaudit.log_relation = on;

-- Apply configuration
SELECT pg_reload_conf();
```

### 🔑 Identification & Authentication (IA)

#### Supported Authentication Methods

| Method | MFA Support | PIV/CAC | SSO | Recommendation |
|--------|------------|---------|-----|----------------|
| **OIDC/SAML** | ✅ Yes | ✅ Yes | ✅ Yes | **Preferred** for enterprise |
| **LDAP/AD** | ⚠️ Via LDAP | ❌ No | ✅ Yes | Good for on-premise |
| **GitHub OAuth** | ✅ Yes | ❌ No | ✅ Yes | Good for development teams |
| **Local Accounts** | ❌ No | ❌ No | ❌ No | Admin/emergency only |

#### OIDC Configuration Example

```yaml
# config/vulcan.yml
oidc:
  enabled: true
  issuer_url: https://login.example.com
  client_id: vulcan-prod
  client_secret: <%= ENV['OIDC_SECRET'] %>
  scope: "openid profile email"
  
  # Advanced Settings
  discovery: true                    # Auto-discover endpoints
  response_type: "code"              # Authorization code flow
  prompt: "select_account"           # Force account selection
  max_age: 3600                      # Force re-auth after 1 hour
  
  # Attribute Mapping
  uid_field: "preferred_username"
  email_field: "email"
  name_field: "name"
```

### 🛡️ System & Communications Protection (SC)

#### TLS Configuration

**Minimum Requirements:**
- TLS 1.2 or higher
- Strong cipher suites only
- Valid certificates from trusted CA
- HSTS enabled with 1-year max-age

**NGINX Configuration:**
```nginx
server {
    listen 443 ssl http2;
    server_name vulcan.example.com;
    
    # TLS Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;
    
    # Rate Limiting
    limit_req zone=vulcan_api burst=20 nodelay;
    limit_req_status 429;
    
    location / {
        proxy_pass http://vulcan_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Deployment Configurations

### Production Deployment Checklist

#### Pre-Deployment
- [ ] Security review completed
- [ ] Penetration testing performed
- [ ] STIG compliance validated
- [ ] Backup procedures tested
- [ ] Incident response plan documented

#### Application Configuration
- [ ] Production environment variables set
- [ ] TLS certificates installed and valid
- [ ] Session timeout configured (≤10 minutes)
- [ ] Welcome banner configured
- [ ] External authentication enabled
- [ ] Local registration disabled
- [ ] Debug mode disabled
- [ ] Error messages sanitized

#### Infrastructure Security
- [ ] Network segmentation implemented
- [ ] Firewall rules configured (allow only 443)
- [ ] Database on separate network segment
- [ ] Load balancer configured with TLS
- [ ] DDoS protection enabled
- [ ] Rate limiting configured
- [ ] WAF rules applied

#### Monitoring & Logging
- [ ] Centralized logging configured
- [ ] Log retention policies set
- [ ] SIEM integration tested
- [ ] Alert rules configured
- [ ] Audit log review process established

### Container Security

```dockerfile
# Secure Dockerfile Example
FROM ruby:3.3.9-slim AS production

# Security: Run as non-root user
RUN groupadd -r app && useradd -r -g app app

# Security: Install only required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        postgresql-client \
        nodejs && \
    rm -rf /var/lib/apt/lists/*

# Security: Set secure permissions
WORKDIR /app
COPY --chown=app:app . .

# Security: No secrets in image
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Security: Run as non-root
USER app

# Security: Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Security: Minimal exposure
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### Kubernetes Security

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vulcan
spec:
  template:
    spec:
      # Security Context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        
      containers:
      - name: vulcan
        image: mitre/vulcan:latest
        
        # Security Settings
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
              - ALL
        
        # Resource Limits
        resources:
          limits:
            memory: "1Gi"
            cpu: "500m"
          requests:
            memory: "512Mi"
            cpu: "250m"
        
        # Liveness/Readiness
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          
---
# Network Policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vulcan-netpol
spec:
  podSelector:
    matchLabels:
      app: vulcan
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: nginx
    ports:
    - port: 3000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - port: 5432
```

## Monitoring & Incident Response

### Security Metrics Dashboard

Monitor these key security indicators:

| Metric | Threshold | Alert Level | Response |
|--------|-----------|-------------|----------|
| Failed login attempts | >5 in 15 min | High | Lock account, investigate |
| Privilege escalation attempts | Any | Critical | Immediate investigation |
| Mass data export | >1000 records | Medium | Review and validate |
| Configuration changes | Any | Low | Log and review daily |
| New admin accounts | Any | High | Verify authorization |
| Unusual access patterns | Deviation >3σ | Medium | Investigate anomaly |

### Incident Response Playbook

#### 1. Detection & Analysis
```bash
# Check recent authentication failures
grep "authentication_failed" /var/log/vulcan/production.log | tail -100

# Review admin actions
grep "admin_action" /var/log/vulcan/audit.log | tail -50

# Check for data exfiltration
grep "export\|download" /var/log/vulcan/access.log | awk '{print $1}' | sort | uniq -c
```

#### 2. Containment
```bash
# Disable compromised account
rails console
User.find_by(email: 'compromised@example.com').lock_access!

# Block IP address
iptables -A INPUT -s <malicious_ip> -j DROP

# Revoke all sessions
Rails.cache.clear
```

#### 3. Eradication & Recovery
- Reset affected passwords
- Review and revoke API keys
- Patch identified vulnerabilities
- Restore from clean backups if needed

#### 4. Post-Incident
- Document timeline and actions
- Update security controls
- Conduct lessons learned session
- Update incident response procedures

## Compliance Validation

### Automated Compliance Checks

```ruby
# spec/compliance/nist_spec.rb
require 'rails_helper'

RSpec.describe "NIST SP 800-53 Compliance" do
  describe "AC-12: Session Termination" do
    it "enforces session timeout" do
      expect(Settings.session_timeout).to be <= 10.minutes
    end
    
    it "provides logout capability" do
      expect(page).to have_button("Log Out")
    end
  end
  
  describe "AU-03: Audit Content" do
    it "logs required event attributes" do
      log_entry = JSON.parse(File.read('/var/log/vulcan/audit.log').last)
      expect(log_entry).to include("timestamp", "user_id", "action", "result")
    end
  end
end
```

### Manual Validation Checklist

**Quarterly Reviews:**
- [ ] User access review
- [ ] Privileged account audit
- [ ] Log retention verification
- [ ] Certificate expiration check
- [ ] Security patch status

**Annual Requirements:**
- [ ] Penetration testing
- [ ] Security control assessment
- [ ] Disaster recovery test
- [ ] Security awareness training
- [ ] Policy and procedure review

## Known Limitations & Roadmap

### Current Limitations

| Control | Gap | Workaround | Target Resolution |
|---------|-----|------------|-------------------|
| AC-10 | No session limits per user | Monitor via SIEM | Q1 2025 (Issue #634) |
| AC-12(02) | No logout confirmation | Check audit logs | Q1 2025 (Issue #635) |
| AU-05 | No built-in log overflow handling | External log rotation | Use log management system |

### Security Roadmap

**Q4 2024:**
- ✅ OIDC auto-discovery
- ✅ Enhanced audit logging
- ✅ Container security hardening

**Q1 2025:**
- ⏳ Session limits per user
- ⏳ Logout confirmation
- ⏳ FIPS 140-2 cryptography mode
- ⏳ Built-in MFA for local accounts

**Q2 2025:**
- 📋 Zero Trust architecture support
- 📋 Enhanced RBAC with custom roles
- 📋 Automated compliance reporting

## Configuration Verification & Cross-References

### Source Code Validation

This table provides direct links to the Vulcan source code that implements each security control:

| Control Category | Feature | Implementation Location | Status |
|-----------------|---------|------------------------|--------|
| **Session Management** | Session Timeout | [`config/vulcan.default.yml:29`](https://github.com/mitre/vulcan/blob/master/config/vulcan.default.yml#L29)<br>[`config/initializers/devise.rb:161`](https://github.com/mitre/vulcan/blob/master/config/initializers/devise.rb#L161) | ✅ Implemented<br>⚠️ Note: Defaults to 60 min, set to 10 min for compliance |
| **System Banner** | Welcome Text | [`config/vulcan.default.yml:11`](https://github.com/mitre/vulcan/blob/master/config/vulcan.default.yml#L11)<br>[`app/views/devise/shared/_what_is_vulcan.html.haml:4`](https://github.com/mitre/vulcan/blob/master/app/views/devise/shared/_what_is_vulcan.html.haml#L4) | ✅ Implemented |
| **Audit Logging** | User Auditing | [`app/models/user.rb:8`](https://github.com/mitre/vulcan/blob/master/app/models/user.rb#L8) | ✅ Implemented |
| **Audit Logging** | Component Auditing | [`app/models/component.rb:42`](https://github.com/mitre/vulcan/blob/master/app/models/component.rb#L42) | ✅ Implemented |
| **OIDC** | Auto-Discovery | [`config/initializers/oidc_startup_validation.rb`](https://github.com/mitre/vulcan/blob/master/config/initializers/oidc_startup_validation.rb) | ✅ Implemented |
| **LDAP** | Configuration | [`config/vulcan.default.yml:35-44`](https://github.com/mitre/vulcan/blob/master/config/vulcan.default.yml#L35) | ✅ Implemented |
| **Authorization** | RBAC | [`app/controllers/application_controller.rb:16-22`](https://github.com/mitre/vulcan/blob/master/app/controllers/application_controller.rb#L16) | ✅ Implemented |
| **Session Limits** | Per-User Limits | [Issue #634](https://github.com/mitre/vulcan/issues/634) | 🚧 In Development |
| **Logout Message** | Confirmation | [Issue #635](https://github.com/mitre/vulcan/issues/635) | 🚧 In Development |
| **Session Timeout Default** | 10 min default | [Issue #685](https://github.com/mitre/vulcan/issues/685) | 📋 Planned |
| **CSRF Documentation** | Explicit validation | [Issue #686](https://github.com/mitre/vulcan/issues/686) | 📋 Planned |

### Configuration Clarifications

Based on source code analysis, the following clarifications apply:

| Configuration | Documentation States | Actual Implementation | Action Required |
|--------------|---------------------|----------------------|-----------------|
| **Session Timeout** | 10 minutes required | Defaults to 60 minutes | ⚠️ **Must set** `VULCAN_SESSION_TIMEOUT=10m` |
| **Admin Timeout** | Separate timeout | Uses same timeout | ℹ️ No separate admin timeout available |
| **CSRF Protection** | Enabled | Rails default (enabled) | ✅ No action needed |
| **Strong Parameters** | Required | Rails default (enabled) | ✅ No action needed |
| **Log Rotation** | External required | Logs to stdout | ⚠️ **Must configure** log management system |

### Implementation Roadmap

The following improvements are tracked as GitHub issues:

| Priority | Issue | Description | Target |
|----------|-------|-------------|--------|
| **High** | [#685](https://github.com/mitre/vulcan/issues/685) | Change default session timeout to 10 minutes | v2.3.0 |
| **High** | [#635](https://github.com/mitre/vulcan/issues/635) | Add logout confirmation message | v2.3.0 |
| **Medium** | [#634](https://github.com/mitre/vulcan/issues/634) | Implement per-user session limits | v2.3.0 |
| **Medium** | [#686](https://github.com/mitre/vulcan/issues/686) | Document CSRF protection explicitly | v2.3.0 |

These improvements will be addressed as part of the Vue 3 migration and Turbolinks removal work in v2.3.0.

## Resources & Support

### Documentation
- [NIST SP 800-53 Rev 5](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [Application Security & Development STIG](https://public.cyber.mil/stigs/)
- [Vulcan Security Updates](https://github.com/mitre/vulcan/security)

### Support Contacts
- **Security Issues:** saf-security@mitre.org
- **General Support:** saf@mitre.org
- **GitHub Issues:** https://github.com/mitre/vulcan/issues

### Compliance Artifacts
Available in `/docs/compliance/`:
- Security Control Matrix (Excel)
- POAM Template
- Risk Assessment Template
- Incident Response Plan Template
- Configuration Baseline

---

**Document Version:** 2.3.0  
**Last Updated:** December 2024  
**Classification:** UNCLASSIFIED  
**Distribution:** Public Release

*This document is maintained as part of the Vulcan project and updated with each security-relevant release.*