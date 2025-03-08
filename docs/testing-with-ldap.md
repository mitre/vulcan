# Testing with LDAP Support

This guide explains how to run tests that require LDAP authentication in Vulcan. The provided infrastructure automatically adapts to different system architectures (including M1/M2/M3 Macs with ARM processors).

## Prerequisites

- Docker and Docker Compose installed
- Ruby environment set up for Vulcan development

## Running Tests with LDAP Support

We've created a convenience script that sets up the necessary Docker containers for PostgreSQL and LDAP, and runs tests with the correct environment variables:

```bash
# Run all tests with LDAP support
bin/test-with-ldap

# Run specific LDAP tests only
bin/test-with-ldap spec/features/ldap_login_spec.rb

# Run specific tests with tags
bin/test-with-ldap --tag ldap
```

## What the Script Does

1. Detects your system architecture (ARM or x86_64)
2. Starts Docker containers for:
   - PostgreSQL database
   - LDAP server pre-configured for testing (bitnami/openldap)
3. Sets the appropriate environment variables for LDAP configuration
4. Runs the tests with the correct configuration

## Manual Configuration

If you prefer to run tests manually, you'll need to set these environment variables:

```bash
VULCAN_ENABLE_LDAP=true
VULCAN_LDAP_ATTRIBUTE=mail
VULCAN_LDAP_BIND_DN="cn=admin,dc=planetexpress,dc=com"
VULCAN_LDAP_BASE="ou=people,dc=planetexpress,dc=com"
VULCAN_LDAP_PORT=389
VULCAN_LDAP_ADMIN_PASS="GoodNewsEveryone"
```

## LDAP Test Users

The LDAP server is pre-configured with the following test users:

- Username: `zoidberg@planetexpress.com`
- Password: `zoidberg`

## Troubleshooting

If you encounter issues:

1. Check Docker container status:
   ```bash
   docker-compose -f docker-compose.test.yml ps
   ```

2. Check LDAP logs:
   ```bash
   docker-compose -f docker-compose.test.yml logs ldap-test
   ```

3. Try manually connecting to the LDAP server:
   ```bash
   ldapsearch -x -H ldap://localhost:389 -D "cn=admin,dc=planetexpress,dc=com" -w "GoodNewsEveryone" -b "dc=planetexpress,dc=com"
   ```

4. Remove containers and try again:
   ```bash
   docker-compose -f docker-compose.test.yml down
   bin/test-with-ldap
   ```