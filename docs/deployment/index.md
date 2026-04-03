# Deployment Options

Choose the deployment method that fits your infrastructure and team.

## Decision Guide

| Factor | [Docker](docker) | [Heroku](heroku) | [Kubernetes](kubernetes) | [Bare Metal](bare-metal) |
|--------|:-:|:-:|:-:|:-:|
| **Setup time** | Minutes | Minutes | Hours | Hours |
| **Ops overhead** | Low | Minimal | Medium | High |
| **Scaling** | Manual | Auto | Auto | Manual |
| **SSL/TLS** | Reverse proxy | Built-in | Ingress | Manual |
| **Cost** | Infrastructure | Platform fee | Infrastructure | Infrastructure |
| **Best for** | Small teams, on-prem | Quick start, prototyping | Large orgs, multi-tenant | Full control, air-gapped |

## Quick Recommendations

**Just trying Vulcan?** Start with [Docker](docker) — single command to run.

**Production for a small team?** [Docker](docker) with a reverse proxy (nginx/traefik) for SSL.

**Managed platform?** [Heroku](heroku) handles infrastructure, SSL, and backups.

**Enterprise / multi-tenant?** [Kubernetes](kubernetes) with Helm chart for scaling and isolation.

**Air-gapped / classified network?** [Bare Metal](bare-metal) for full control without container dependencies.

## Common Requirements (All Deployments)

Every production deployment needs:

1. **Secrets** — `SECRET_KEY_BASE`, `CIPHER_PASSWORD`, `CIPHER_SALT` (generate with `openssl rand -hex 64`)
2. **PostgreSQL 18** — dedicated database with secure password
3. **Authentication** — at least one provider (OIDC recommended, LDAP, or local login)
4. **SSL/TLS** — HTTPS for all production traffic

See [Configuration](/getting-started/configuration) for the full "What You Must Provide" checklist.

## Authentication Setup

All deployment methods support the same authentication providers:

- **[OIDC/Okta](auth/oidc-okta)** — recommended for production (Okta, Azure AD, Keycloak, Auth0)
- **[LDAP](auth/ldap)** — Active Directory / OpenLDAP integration
- **[GitHub OAuth](auth/github)** — lightweight OAuth for development teams
- **Local login** — email/password (enabled by default, disable for production)
