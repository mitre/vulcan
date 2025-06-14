# Kubernetes Deployment: Settings Migration Guide

This guide helps Kubernetes users migrate Vulcan to the new settings system.

## Quick Start

1. **Run preflight check** to validate your configuration:
   ```bash
   docker run -it --rm \
     --env-file your-env-file \
     mitre/vulcan:latest \
     bin/preflight-check --k8s-example
   ```

2. **Update your deployment** with required environment variables

3. **Run database migration** as a Kubernetes Job

## Required Changes

### 1. ConfigMap for Environment Variables

Create a ConfigMap with all required settings:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vulcan-config
  namespace: vulcan
data:
  # Essential Configuration
  RAILS_ENV: "production"
  VULCAN_CONTACT_EMAIL: "admin@your-org.com"
  VULCAN_APP_URL: "https://vulcan.your-org.com"

  # Authentication - Choose at least one

  # Option A: OIDC/SSO (Recommended for enterprise)
  VULCAN_ENABLE_OIDC: "true"
  VULCAN_OIDC_ISSUER_URL: "https://your-idp.com/oauth2/default"
  VULCAN_OIDC_REDIRECT_URI: "https://vulcan.your-org.com/users/auth/oidc/callback"

  # Option B: LDAP
  VULCAN_ENABLE_LDAP: "true"
  VULCAN_LDAP_HOST: "ldap.your-org.com"
  VULCAN_LDAP_PORT: "636"
  VULCAN_LDAP_ENCRYPTION: "simple_tls"
  VULCAN_LDAP_BASE: "dc=your-org,dc=com"
  VULCAN_LDAP_TITLE: "Corporate LDAP"

  # Option C: Local Login (not recommended for production)
  VULCAN_ENABLE_LOCAL_LOGIN: "true"
  VULCAN_ENABLE_USER_REGISTRATION: "false"

  # Optional Services
  VULCAN_ENABLE_SMTP: "true"
  VULCAN_SMTP_ADDRESS: "smtp.your-org.com"
  VULCAN_SMTP_PORT: "587"
  VULCAN_SMTP_DOMAIN: "your-org.com"
  VULCAN_SMTP_AUTHENTICATION: "plain"
  VULCAN_SMTP_ENABLE_STARTTLS_AUTO: "true"
```

### 2. Secret for Sensitive Values

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vulcan-secrets
  namespace: vulcan
type: Opaque
stringData:
  # Database
  DATABASE_URL: "postgres://vulcan:password@postgres:5432/vulcan_production"

  # Rails
  SECRET_KEY_BASE: "generate-with-rails-secret"

  # OIDC
  VULCAN_OIDC_CLIENT_ID: "your-client-id"
  VULCAN_OIDC_CLIENT_SECRET: "your-client-secret"

  # LDAP
  VULCAN_LDAP_BIND_DN: "cn=vulcan,ou=services,dc=your-org,dc=com"
  VULCAN_LDAP_ADMIN_PASS: "ldap-bind-password"

  # SMTP
  VULCAN_SMTP_SERVER_USERNAME: "vulcan@your-org.com"
  VULCAN_SMTP_SERVER_PASSWORD: "smtp-password"

  # Slack
  VULCAN_SLACK_API_TOKEN: "xoxb-your-token"
  VULCAN_SLACK_CHANNEL_ID: "C1234567890"
```

### 3. Migration Job

Run the database migration as a Kubernetes Job:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: vulcan-migrate-settings
  namespace: vulcan
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migrate
        image: mitre/vulcan:latest
        command:
        - /bin/bash
        - -c
        - |
          echo "Running database migrations..."
          bundle exec rails db:migrate
          echo "Running preflight check..."
          bin/preflight-check --check-db
        envFrom:
        - configMapRef:
            name: vulcan-config
        - secretRef:
            name: vulcan-secrets
```

### 4. Update Deployment

Update your Vulcan deployment to use the ConfigMap and Secret:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vulcan
  namespace: vulcan
spec:
  replicas: 2
  selector:
    matchLabels:
      app: vulcan
  template:
    metadata:
      labels:
        app: vulcan
    spec:
      initContainers:
      # Preflight check before starting
      - name: preflight-check
        image: mitre/vulcan:latest
        command: ["bin/preflight-check"]
        envFrom:
        - configMapRef:
            name: vulcan-config
        - secretRef:
            name: vulcan-secrets
      containers:
      - name: vulcan
        image: mitre/vulcan:latest
        ports:
        - containerPort: 3000
        envFrom:
        - configMapRef:
            name: vulcan-config
        - secretRef:
            name: vulcan-secrets
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
```

## Helm Chart Updates

If using Helm, update your `values.yaml`:

```yaml
# values.yaml
config:
  railsEnv: production
  contactEmail: admin@your-org.com
  appUrl: https://vulcan.your-org.com

auth:
  oidc:
    enabled: true
    issuerUrl: https://your-idp.com/oauth2/default
    clientId: your-client-id
    clientSecret: your-client-secret  # Use secrets management!

  ldap:
    enabled: false

  localLogin:
    enabled: false

services:
  smtp:
    enabled: true
    address: smtp.your-org.com
    port: 587
    username: vulcan@your-org.com
    password: ""  # Use secrets management!

  slack:
    enabled: false

# Existing database config remains the same
postgresql:
  enabled: true
  auth:
    database: vulcan_production
    username: vulcan
    password: ""  # Use secrets management!
```

Update your Helm templates to generate the ConfigMap and Secret from these values.

## Validation Steps

1. **Before deploying**, run preflight check:
   ```bash
   kubectl run vulcan-preflight --rm -it --restart=Never \
     --image=mitre/vulcan:latest \
     --env-from=configMapRef=vulcan-config \
     --env-from=secretRef=vulcan-secrets \
     -- bin/preflight-check --check-db
   ```

2. **Check migration status**:
   ```bash
   kubectl exec -it deployment/vulcan -- rails db:migrate:status
   ```

3. **Verify settings loaded**:
   ```bash
   kubectl exec -it deployment/vulcan -- rails runner "puts Setting.all.map(&:var)"
   ```

## Troubleshooting

### Pod Fails to Start

1. Check preflight logs:
   ```bash
   kubectl logs -l app=vulcan -c preflight-check
   ```

2. Common issues:
   - Missing required environment variables
   - Database not accessible
   - Settings table not created (migration not run)

### Authentication Not Working

1. Verify OIDC settings:
   ```bash
   kubectl exec -it deployment/vulcan -- rails console
   > Setting.oidc_enabled
   > Setting.oidc_args
   ```

2. Check logs for initialization errors:
   ```bash
   kubectl logs -l app=vulcan | grep -i "oidc\|ldap\|settings"
   ```

### Environment Variables Not Loading

1. Verify ConfigMap/Secret are mounted:
   ```bash
   kubectl describe pod -l app=vulcan
   ```

2. Check environment in pod:
   ```bash
   kubectl exec -it deployment/vulcan -- printenv | grep VULCAN
   ```

## Best Practices

1. **Use Secrets Management**: Don't put passwords in ConfigMaps
   - Use Kubernetes Secrets
   - Consider HashiCorp Vault, AWS Secrets Manager, etc.
   - Use Sealed Secrets for GitOps

2. **Set Resource Limits**:
   ```yaml
   resources:
     requests:
       memory: "512Mi"
       cpu: "500m"
     limits:
       memory: "1Gi"
       cpu: "1000m"
   ```

3. **Use Health Checks**: The preflight check can be used as an init container

4. **Rolling Updates**: The new settings system supports zero-downtime deployments

5. **Backup Before Migration**:
   ```bash
   kubectl exec -it deployment/vulcan -- pg_dump $DATABASE_URL > backup.sql
   ```

## Rollback Plan

If issues occur:

1. Scale down deployment:
   ```bash
   kubectl scale deployment/vulcan --replicas=0
   ```

2. Rollback migration:
   ```bash
   kubectl exec -it deployment/vulcan -- rails db:rollback
   ```

3. Deploy previous version:
   ```bash
   kubectl set image deployment/vulcan vulcan=mitre/vulcan:previous-version
   ```

4. Restore configuration files if needed