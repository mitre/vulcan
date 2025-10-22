# Health Monitoring

Vulcan v2.3.0+ includes comprehensive health check endpoints for Kubernetes probes, load balancers, and monitoring dashboards.

## Health Check Endpoints

### `/up` - Liveness Check

Rails 8 built-in health check. Returns 200 if the application process is running.

```bash
curl http://localhost:3000/up
# Returns: HTTP 200 with green HTML page
```

**Kubernetes Usage:**
```yaml
livenessProbe:
  httpGet:
    path: /up
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10
```

### `/health_check` - Comprehensive Check

Validates database connectivity and migration status using the health_check gem.

```bash
# Plain text
curl http://localhost:3000/health_check
# Returns: "ok" or error message

# JSON format
curl http://localhost:3000/health_check.json
# Returns: {"healthy":true,"message":"success"}
```

**Kubernetes Usage:**
```yaml
readinessProbe:
  httpGet:
    path: /health_check
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 5
```

### `/health_check/database` - Database Check

Checks only database connectivity. Faster than full health check.

```bash
curl http://localhost:3000/health_check/database
# Returns: "ok" if database is accessible
```

**Kubernetes Usage:**
```yaml
readinessProbe:
  httpGet:
    path: /health_check/database
    port: 3000
```

### `/health_check/ldap` - LDAP Check

Checks LDAP server connectivity (if LDAP authentication is enabled).

```bash
curl http://localhost:3000/health_check/ldap
# Returns: "ok" if LDAP server is reachable
# Returns: "" (empty) if LDAP is disabled
```

### `/health_check/oidc` - OIDC Check

Checks OIDC issuer connectivity (if OIDC authentication is enabled).

```bash
curl http://localhost:3000/health_check/oidc
# Returns: "ok" if OIDC issuer is reachable
# Returns: "" (empty) if OIDC is disabled
```

## Status Endpoint

### `/status` - Application Status

Provides comprehensive application status including version, health, setup state, and system metrics.

```bash
curl http://localhost:3000/status | jq
```

**Response Structure:**
```json
{
  "application": {
    "name": "Vulcan",
    "version": "2.3.0",
    "rails_version": "8.0.2.1",
    "environment": "production"
  },
  "health": {
    "status": "healthy",
    "database": "connected",
    "ldap": "disabled",
    "oidc": "configured"
  },
  "setup": {
    "admin_user_exists": true,
    "smtp_configured": false,
    "auth_providers": ["local", "oidc"],
    "features": {
      "user_registration": true,
      "project_creation": false,
      "local_login": true
    }
  },
  "system": {
    "uptime_seconds": 3600,
    "database_pool_size": 5,
    "database_connections": 2
  }
}
```

**Use Cases:**
- Deployment verification
- Configuration validation
- Support troubleshooting
- Monitoring dashboards

## Kubernetes Configuration

### Recommended Probe Configuration

```yaml
containers:
- name: vulcan
  image: mitre/vulcan:v2.3.0
  ports:
  - containerPort: 3000
  # Liveness: Is the app running?
  livenessProbe:
    httpGet:
      path: /up
      port: 3000
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
  # Readiness: Can the app serve traffic?
  readinessProbe:
    httpGet:
      path: /health_check/database
      port: 3000
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 3
  # Startup: Wait for slow initialization
  startupProbe:
    httpGet:
      path: /health_check
      port: 3000
    initialDelaySeconds: 0
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 30
```

### Probe Strategy

**Liveness Probe** (`/up`):
- Lightweight check
- Only validates Rails process is alive
- Doesn't check dependencies
- Avoids false restarts from temporary issues

**Readiness Probe** (`/health_check/database`):
- Validates critical dependencies
- Removes pod from service if unhealthy
- Prevents routing traffic to broken pods
- Checks database connectivity

**Startup Probe** (`/health_check`):
- Comprehensive validation during startup
- Allows slow initialization (Rails boot, asset loading)
- Disables other probes until passes
- Prevents premature restarts

## Monitoring Integration

### Prometheus

The health check endpoints can be monitored with Prometheus:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vulcan
spec:
  selector:
    matchLabels:
      app: vulcan
  endpoints:
  - port: http
    path: /health_check.json
    interval: 30s
```

### Datadog / New Relic

Configure HTTP check monitors:
- URL: `https://vulcan.example.com/health_check`
- Expected: `200` status code
- Expected body: `ok`

### Custom Monitoring

Poll the `/status` endpoint for detailed metrics:

```bash
#!/bin/bash
# Check if admin user exists
STATUS=$(curl -s http://localhost:3000/status)
ADMIN_EXISTS=$(echo $STATUS | jq -r '.setup.admin_user_exists')

if [ "$ADMIN_EXISTS" != "true" ]; then
  echo "WARNING: No admin user configured!"
fi
```

## Troubleshooting

### Health Check Failing

1. Check specific endpoint:
   ```bash
   curl http://localhost:3000/health_check/database
   ```

2. View detailed status:
   ```bash
   curl http://localhost:3000/status | jq
   ```

3. Check application logs:
   ```bash
   kubectl logs -n vulcan deployment/vulcan
   ```

### Database Connection Issues

If `/health_check/database` returns errors:
- Verify DATABASE_URL is correct
- Check PostgreSQL is running
- Verify network connectivity
- Check database credentials

### Authentication Provider Issues

If LDAP/OIDC checks fail:
- Verify provider URLs are accessible
- Check firewall rules
- Validate credentials
- Review provider-specific logs
