# Vulcan

[![Run Test Suite on Draft Release Creation, Push, and Pull Request to master](https://github.com/mitre/vulcan/actions/workflows/run-tests.yml/badge.svg)](https://github.com/mitre/vulcan/actions/workflows/run-tests.yml) [![Push Vulcan to Docker Hub on successful test suite run](https://github.com/mitre/vulcan/actions/workflows/push-to-docker.yml/badge.svg)](https://github.com/mitre/vulcan/actions/workflows/push-to-docker.yml)
## Description

Vulcan is a tool to help streamline the process of creating STIG-ready securiy guidance documentation and InSpec automated validation profiles.

Vulcan models the STIG intent form and the process of aligning security controls from high-level DISA Security Requirements Guides (SRGs) into [Security Technical Implementation Guides](public.cyber.mil/stigs) (STIGs) tailored to a particular system component. STIG-ready content developed with Vulcan can be provided to DISA for peer review and formal publishing as a STIG.  Vulcan allows the guidance author to develop both human-readable instructions and machine-readable automated validation code at the same time.

## Features

* Model the STIG creation process between the creator (vendor) and the approver (sponsor)
* Write and test InSpec code on a local system, or across SSH, AWS, and Docker targets
* Easily view control status and revision history
* Enable distributed authorship with multiple authors working on sets of controls and reviewing each others' work.
* Enable looking up related controls (controls using the same SRG ID) in published STIGs while auhtoring or reviewing a control.
* View DISA published STIG Contents.
* Confidential data in the database is encrypted using symmetric encryption
* Authenticate via the local server, through GitHub, LDAP, or OKTA/OIDC providers
* Email and Slack notification enabled

## Latest Release: [v2.1.8](https://github.com/mitre/vulcan/releases/tag/v2.1.8)

You can pull the Docker image for the latest release with the following command:

```bash
  docker pull mitre/vulcan:v2.1.8
```

For more details on this release and previous ones, check the [Changelog](https://vulcan.mitre.org/CHANGELOG.html).

## Deploy Vulcan

[Deploying Vulcan in Production](https://vulcan.mitre.org/docs/)&nbsp;&nbsp;&nbsp;[<img src="public/GitHub-Mark-Light-64px.png#gh-dark-mode-only" width="20"/>](https://pages.github.com/)[<img src="public/GitHub-Mark-64px.png#gh-light-mode-only" width="20"/>](https://pages.github.com/)

## Deployment Dependencies

For Ruby (on Ubuntu):

* Ruby
* `build-essentials`
* Bundler
* `libq-dev`
* nodejs

### Run With Ruby

#### Setup Ruby

1. Install the version of Ruby specified in `.ruby-version`
2. Install postgres and rbenv
3. Run `gem install foreman`
4. Run `rbenv install`
5. Run `bin/setup`

  >> **Note**: `bin/setup` will install the JS dependencies andprepare the database.

6. Run `rails db:seed` to seed the database.

#### Running with Ruby

Make sure you have run the setup steps at least once before following these steps!

1. ensure postgres is running
2. foreman start -f Procfile.dev
3. Navigate to `http://127.0.0.1:3000`

#### Test User

For testing purposes in the development environment, you can use the following credentials:

**Email**: <admin@example.com>

**Password**: 1234567ab!

#### Stopping Vulcan

1. Stop Vulcan by doing `ctrl + c`
2. Stop the postgres server

## Configuration

See `docker-compose.yml` for container configuration options.

For a complete list of environment variables that can be used to configure Vulcan, see [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md).

Documentation on how to configure additional Vulcan settings such as SMTP, LDAP, etc, are available on the [Vulcan website](https://vulcan.mitre.org/docs/config.html).

### Production Configuration

The production Docker image includes sensible defaults for containerized deployments:

```bash
# Environment setup
RAILS_ENV=production
NODE_ENV=production
RACK_ENV=production

# Logging configuration
RAILS_LOG_TO_STDOUT=true
RAILS_LOG_LEVEL=info

# Asset serving for containerized deployments
RAILS_SERVE_STATIC_FILES=true

# Performance and concurrency settings
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2

# Memory optimization
MALLOC_ARENA_MAX=2
```

These defaults ensure proper logging for container orchestration platforms (Docker, Kubernetes) and log aggregation systems (ELK stack, Splunk, etc.). The performance settings provide a good balance for most production workloads while remaining conservative on resource usage.

All settings can be overridden at runtime by setting environment variables in your deployment configuration.

### OKTA/OIDC Authentication

Vulcan supports authentication via OKTA or any OpenID Connect (OIDC) provider with **automatic endpoint discovery** to simplify configuration.

#### Quick Setup (Recommended)

**New in v2.2+**: Vulcan automatically discovers OIDC endpoints using the provider's `.well-known/openid-configuration` endpoint, reducing configuration to just 4 essential variables:

1. **Create an OIDC Application** in your provider:
   - **Okta**: Create a new "Web" application in your Okta admin dashboard
   - **Auth0**: Create a new "Regular Web Application" 
   - **Keycloak**: Create a new "openid-connect" client
   - **Azure AD**: Register a new application with "Web" platform
   - Set the Sign-in redirect URI to: `https://your-domain/users/auth/oidc/callback`
   - Set the Sign-out redirect URI to: `https://your-domain`
   - Note your Client ID and Client Secret

2. **Configure Vulcan Environment Variables**:
   ```bash
   # Essential configuration (only 4 variables needed!)
   VULCAN_ENABLE_OIDC=true
   VULCAN_OIDC_ISSUER_URL=https://your-domain.okta.com  # Your provider's issuer URL
   VULCAN_OIDC_CLIENT_ID=your-client-id
   VULCAN_OIDC_CLIENT_SECRET=your-client-secret
   VULCAN_OIDC_REDIRECT_URI=https://your-domain/users/auth/oidc/callback

   # Optional: Custom provider display name
   VULCAN_OIDC_PROVIDER_TITLE=Okta
   ```

3. **Restart Vulcan** to apply the configuration changes

#### Provider Examples

**Okta**:
```bash
VULCAN_OIDC_ISSUER_URL=https://dev-12345.okta.com
# Vulcan auto-discovers: authorization, token, userinfo, and logout endpoints
```

**Auth0**:
```bash
VULCAN_OIDC_ISSUER_URL=https://your-domain.auth0.com
# Vulcan auto-discovers: authorization, token, userinfo, and logout endpoints
```

**Keycloak**:
```bash
VULCAN_OIDC_ISSUER_URL=https://keycloak.example.com/realms/your-realm
# Vulcan auto-discovers: authorization, token, userinfo, and logout endpoints
```

#### Manual Configuration (Legacy)

If you need to disable auto-discovery or override specific endpoints:

```bash
# Disable auto-discovery
VULCAN_OIDC_DISCOVERY=false

# Manual endpoint configuration (when discovery is disabled)
VULCAN_OIDC_AUTHORIZATION_URL=https://provider.com/oauth2/v1/authorize
VULCAN_OIDC_TOKEN_URL=https://provider.com/oauth2/v1/token
VULCAN_OIDC_USERINFO_URL=https://provider.com/oauth2/v1/userinfo
VULCAN_OIDC_JWKS_URI=https://provider.com/oauth2/v1/keys
```

#### Features

- **🔄 Auto-Discovery**: Automatically configures endpoints from provider metadata
- **🔒 Security**: HTTPS enforcement, issuer validation, and secure fallbacks
- **⚡ Performance**: Session caching with 1-hour TTL to minimize discovery calls
- **🛡️ Resilience**: Graceful fallback to manual configuration if discovery fails
- **📊 Monitoring**: Comprehensive logging for troubleshooting and monitoring

Users will see a "Login with [Provider]" button on the sign-in page. First-time users will have accounts automatically created upon successful authentication.

### Container Deployment & Logging

When deploying Vulcan in containerized environments (Docker, AWS ECS, Kubernetes), you can enable enhanced logging for better visibility and monitoring:

#### Container Logging Configuration

```bash
# Enable container-friendly logging
RAILS_LOG_TO_STDOUT=true

# Enable JSON structured logging for CloudWatch/monitoring systems
STRUCTURED_LOGGING=true
```

#### Features

- **🐳 Auto-Detection**: Automatically detects Docker, ECS, and Kubernetes environments
- **📋 JSON Logs**: Structured JSON output for CloudWatch, Splunk, and other log aggregators
- **🔍 OIDC Visibility**: All OIDC auto-discovery events are logged with detailed context
- **🏷️ Request Tracking**: Includes request IDs for tracing user sessions

#### Container Examples

**Docker Compose**:
```yaml
services:
  vulcan:
    environment:
      RAILS_LOG_TO_STDOUT: "true"
      STRUCTURED_LOGGING: "true"
      # Other environment variables...
```

**AWS ECS Task Definition**:
```json
{
  "environment": [
    {"name": "RAILS_LOG_TO_STDOUT", "value": "true"},
    {"name": "STRUCTURED_LOGGING", "value": "true"}
  ]
}
```

**Kubernetes Deployment**:
```yaml
env:
  - name: RAILS_LOG_TO_STDOUT
    value: "true"
  - name: STRUCTURED_LOGGING
    value: "true"
```

This ensures all application logs, including OIDC authentication events, are visible in your container orchestration platform's logging system.

## Tasks

### STIG/SRG Puller Task

This application includes a rake task that pulls published Security Requirements Guides (SRGs) and Security Technical Implementation Guides (STIGs) from
public.cyber.mil and saves them locally. This task can be executed manually or set up to run on a schedule in a production environment.

#### Manual Execution

You can manually execute the STIG/SRG puller task by running the following command in your terminal:

```shell
bundle exec rails stig_and_srg_puller:pull
```

#### Scheduling the Task in Production

If you wish to automate the execution of this task in a production environment, you can set up a task scheduler on your hosting platform.
The configuration will depend on your specific hosting service.

Generally, you will need to create a job that runs the following command:

```shell
bundle exec rails stig_and_srg_puller:pull
```

You can set the frequency of this task according to your preference or needs. However, it's important to consider the volume of data being pulled
and the impact on the application's performance when deciding on the frequency.

>> Please refer to your hosting platform's documentation or support services for specific instructions on how to set up scheduled tasks or cron jobs.

## Releasing Vulcan

For detailed information about creating a release, please refer to the [release documentation](https://github.com/mitre/vulcan/wiki/Release_vulcan).

### NOTICE

© 2022 The MITRE Corporation.

Approved for Public Release; Distribution Unlimited. Case Number 18-3678.

### NOTICE

MITRE hereby grants express written permission to use, reproduce, distribute, modify, and otherwise leverage this software to the extent permitted by the licensed terms provided in the LICENSE.md file included with this project.

### NOTICE

This software was produced for the U. S. Government under Contract Number HHSM-500-2012-00008I, and is subject to Federal Acquisition Regulation Clause 52.227-14, Rights in Data-General.

No other use other than that granted to the U. S. Government, or to those acting on behalf of the U. S. Government under that Clause is authorized without the express written permission of The MITRE Corporation.

For further information, please contact The MITRE Corporation, Contracts Management Office, 7515 Colshire Drive, McLean, VA 22102-7539, (703) 983-6000.
