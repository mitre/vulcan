# Kubernetes Deployment

## Overview

Vulcan can be deployed to Kubernetes using either the official Helm chart (recommended) or manual Kubernetes manifests. This guide covers both approaches.

## Recommended: Official Helm Chart

The **easiest and most robust** way to deploy Vulcan to Kubernetes:

### Quick Start

```bash
# Add the MITRE Helm repository
helm repo add mitre https://mitre.github.io/vulcan-helm
helm repo update

# Install Vulcan
helm install vulcan mitre/vulcan --namespace vulcan --create-namespace

# Or with custom values
helm install vulcan mitre/vulcan -f my-values.yaml --namespace vulcan --create-namespace
```

### Features

The official Helm chart provides production-ready features:

- ✅ **Health Probes** - Liveness, readiness, and startup probes
- ✅ **High Availability** - PodDisruptionBudget for zero-downtime updates
- ✅ **Security** - Security contexts, NetworkPolicy, non-root containers
- ✅ **Resource Management** - CPU/memory requests and limits
- ✅ **External Database** - Support for AWS RDS, Cloud SQL, etc.
- ✅ **Autoscaling** - Horizontal Pod Autoscaler support
- ✅ **Ingress** - Nginx ingress with TLS support
- ✅ **Monitoring** - Prometheus-ready endpoints

### Resources

- **Repository**: https://github.com/mitre/vulcan-helm
- **Chart Documentation**: [Helm Chart README](https://github.com/mitre/vulcan-helm/blob/main/vulcan/README.md)
- **ArtifactHub**: Coming soon

## Alternative: Manual Kubernetes Manifests

For learning, customization, or environments where Helm isn't available, you can use manual YAML manifests.

**Note:** These examples are simplified for education. The Helm chart includes additional production features like PodDisruptionBudget, NetworkPolicy, resource limits, and external database support.

### Prerequisites

- Kubernetes cluster (1.21+)
- kubectl configured with cluster access
- PostgreSQL database (can be in-cluster or external)
- Ingress controller (nginx recommended)
- Persistent storage provisioner (for database if in-cluster)
- SSL/TLS certificates (cert-manager recommended)

## Architecture

### Components

1. **Vulcan Web Application** - Rails application pods
2. **PostgreSQL Database** - Data persistence layer
3. **Ingress Controller** - External access and SSL termination
4. **ConfigMaps** - Application configuration
5. **Secrets** - Sensitive credentials
6. **Services** - Internal networking
7. **PersistentVolumeClaims** - Database storage

## Quick Start

### 1. Create Namespace

```bash
kubectl create namespace vulcan
```

### 2. Configure Secrets

Create comprehensive secrets for your deployment:

```yaml
# k8s-vulcan-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: vulcansecrets
  namespace: vulcan
type: Opaque
stringData:
  postgresql-password: "secure_database_password"
  key-base: "$(openssl rand -hex 64)"
  cipher-password: "$(openssl rand -hex 32)"
  cipher-salt: "$(openssl rand -hex 32)"
  ldap-password: "ldap_service_account_password"
  oidc-client-secret: "your_oidc_client_secret"
```

Generate secure values:
```bash
# Generate SECRET_KEY_BASE
echo "key-base: $(openssl rand -hex 64)"

# Generate cipher keys
echo "cipher-password: $(openssl rand -hex 32)"
echo "cipher-salt: $(openssl rand -hex 32)"
```

Apply the secret:
```bash
kubectl apply -f k8s-vulcan-secrets.yaml
```

### 3. Create ConfigMap

```yaml
# k8s-vulcan-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vulcan-config
  namespace: vulcan
data:
  vulcan-config.yml: |
    production:
      welcome_text: "Welcome to Vulcan"
      contact_email: "admin@example.com"
      app_url: "https://vulcan.example.com"
      
      smtp:
        enabled: true
        settings:
          address: smtp.example.com
          port: 587
          domain: example.com
          authentication: plain
          # user_name automatically defaults to contact_email if not specified
          # user_name: admin@example.com  # Override only if different from contact_email
          enable_starttls_auto: true
      
      local_login:
        enabled: true
        email_confirmation: false
        session_timeout: 60
      
      user_registration:
        enabled: true
      
      project_create_permission:
        enabled: true
```

Apply the ConfigMap:
```bash
kubectl apply -f k8s-vulcan-config.yaml
```

### 4. Deploy Vulcan

Complete deployment with all production settings:

```yaml
# k8s-vulcan-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vulcan-web
  namespace: vulcan
  labels:
    app: vulcan-web
spec:
  replicas: 2
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: vulcan-web
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: vulcan-web
    spec:
      automountServiceAccountToken: false  # Security best practice
      containers:
      - name: vulcan-web
        image: mitre/vulcan:v2.3.0
        imagePullPolicy: Always
        ports:
        - containerPort: 3000
          name: vulcan-web
        resources:
          requests:
            cpu: "500m"
            memory: 1Gi
          limits:
            cpu: "1000m"
            memory: 2Gi
        volumeMounts:
        - name: config-volume
          mountPath: /app/config/vulcan.yml
          subPath: vulcan-config.yml
        env:
        # Database Configuration
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: vulcansecrets
              key: postgresql-password
        - name: DATABASE_URL
          value: postgres://vulcan:$(DATABASE_PASSWORD)@postgresql:5432/vulcan_production
        
        # Rails Configuration
        - name: RAILS_ENV
          value: production
        - name: RAILS_SERVE_STATIC_FILES
          value: "true"
        - name: RAILS_LOG_TO_STDOUT
          value: "true"
        - name: FORCE_SSL
          value: "true"  # Set to false for local/dev clusters without ingress TLS
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: vulcansecrets
              key: key-base
        
        # Security Keys
        - name: CIPHER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: vulcansecrets
              key: cipher-password
        - name: CIPHER_SALT
          valueFrom:
            secretKeyRef:
              name: vulcansecrets
              key: cipher-salt
        
        # Application Configuration
        - name: VULCAN_WELCOME_TEXT
          value: "Welcome to Vulcan - Kubernetes Deployment"
        - name: VULCAN_CONTACT_EMAIL
          value: "vulcan-admin@example.com"
        - name: VULCAN_APP_URL
          value: "https://vulcan.example.com"
        - name: VULCAN_SESSION_TIMEOUT
          value: "10"
        
        # LDAP Configuration (if using)
        - name: VULCAN_ENABLE_LDAP
          value: "true"
        - name: VULCAN_LDAP_HOST
          value: "ldap.example.com"
        - name: VULCAN_LDAP_PORT
          value: "636"
        - name: VULCAN_LDAP_TITLE
          value: "Corporate LDAP"
        - name: VULCAN_LDAP_ATTRIBUTE
          value: "sAMAccountName"
        - name: VULCAN_LDAP_ENCRYPTION
          value: "simple_tls"
        - name: VULCAN_LDAP_BIND_DN
          value: "CN=vulcan.svcacct,OU=Service Accounts,DC=example,DC=com"
        - name: VULCAN_LDAP_ADMIN_PASS
          valueFrom:
            secretKeyRef:
              name: vulcansecrets
              key: ldap-password
        - name: VULCAN_LDAP_BASE
          value: "DC=example,DC=com"
        
        # OIDC Configuration (if using)
        - name: VULCAN_ENABLE_OIDC
          value: "false"
        - name: VULCAN_OIDC_ISSUER_URL
          value: "https://your-idp.example.com"
        - name: VULCAN_OIDC_CLIENT_ID
          value: "vulcan-kubernetes"
        - name: VULCAN_OIDC_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: vulcansecrets
              key: oidc-client-secret
        
        # Health Checks
        livenessProbe:
          httpGet:
            path: /up
            port: 3000
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health_check/database
            port: 3000
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /health_check
            port: 3000
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30
      
      volumes:
      - name: config-volume
        configMap:
          name: vulcan-config
---
apiVersion: v1
kind: Service
metadata:
  name: vulcan
  namespace: vulcan
spec:
  selector:
    app: vulcan
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
```

### 4. Configure Ingress

```yaml
# k8s-vulcan-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vulcan
  namespace: vulcan
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - vulcan.example.com
    secretName: vulcan-tls
  rules:
  - host: vulcan.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: vulcan
            port:
              number: 80
```

## Configuration

### ConfigMap for Non-Sensitive Settings

```yaml
# k8s-vulcan-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vulcan-config
  namespace: vulcan
data:
  VULCAN_ENABLE_OIDC: "true"
  VULCAN_OIDC_ISSUER_URL: "https://your-domain.okta.com"
  VULCAN_OIDC_CLIENT_ID: "your-client-id"
  VULCAN_CONTACT_EMAIL: "vulcan-admin@example.com"
  VULCAN_APP_URL: "https://vulcan.example.com"
```

### Database Setup

#### Option 1: External Database

Use a managed database service (RDS, Cloud SQL, etc.) and provide the connection string in the secret.

#### Option 2: In-Cluster PostgreSQL

Deploy PostgreSQL using Helm:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgres bitnami/postgresql \
  --namespace vulcan \
  --set auth.database=vulcan \
  --set auth.username=vulcan \
  --set persistence.size=10Gi
```

### Persistent Storage

For file uploads, configure a PersistentVolume:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: vulcan-uploads
  namespace: vulcan
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
```

Mount in deployment:
```yaml
volumeMounts:
- name: uploads
  mountPath: /app/public/uploads
volumes:
- name: uploads
  persistentVolumeClaim:
    claimName: vulcan-uploads
```

## Database Backup

### Automated Backup CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vulcan-db-backup
  namespace: vulcan
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: postgres-backup
            image: postgres:16-alpine
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
            command:
            - /bin/bash
            - -c
            - |
              DATE=$(date +%Y%m%d_%H%M%S)
              pg_dump -h postgres -U vulcan vulcan > /backup/vulcan_$DATE.sql
              # Upload to S3 or other storage
              # aws s3 cp /backup/vulcan_$DATE.sql s3://backups/vulcan/
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            emptyDir: {}
          restartPolicy: OnFailure
```

## Scaling

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: vulcan-hpa
  namespace: vulcan
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: vulcan
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Monitoring

### Prometheus Metrics

Add annotations for Prometheus scraping:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "3000"
    prometheus.io/path: "/metrics"
```

### Health Checks

Vulcan provides health endpoints:
- `/health` - Basic health check
- `/readiness` - Database connectivity check

## Security Best Practices

1. **Network Policies**: Restrict pod-to-pod communication
2. **Pod Security**: Run as non-root user
3. **Secrets Management**: Use sealed-secrets or external-secrets
4. **RBAC**: Limit service account permissions
5. **Image Security**: Scan images regularly
6. **Resource Limits**: Always set resource requests/limits

### Example Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vulcan-netpol
  namespace: vulcan
spec:
  podSelector:
    matchLabels:
      app: vulcan
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
```

## Troubleshooting

### Common Issues

1. **Database Connection Failed**
   ```bash
   kubectl logs -n vulcan deployment/vulcan
   kubectl describe pod -n vulcan vulcan-xxx
   ```

2. **Asset Compilation Issues**
   ```bash
   kubectl exec -n vulcan deployment/vulcan -- rails assets:precompile
   ```

3. **Migration Pending**
   ```bash
   kubectl exec -n vulcan deployment/vulcan -- rails db:migrate
   ```

### Debug Commands

```bash
# Get pod status
kubectl get pods -n vulcan

# View logs
kubectl logs -n vulcan -l app=vulcan --tail=100

# Execute shell in pod
kubectl exec -it -n vulcan deployment/vulcan -- bash

# Check events
kubectl get events -n vulcan --sort-by='.lastTimestamp'
```

## Production Checklist

- [ ] TLS/SSL configured
- [ ] Database backups configured
- [ ] Monitoring/alerting set up
- [ ] Resource limits defined
- [ ] Network policies in place
- [ ] Secrets properly managed
- [ ] High availability (multiple replicas)
- [ ] Persistent storage for uploads
- [ ] Ingress configured with rate limiting
- [ ] Pod disruption budgets set

## Example Files

Complete example manifests are available in the repository:
- [k8s-vulcan-deployment-example.yaml](https://github.com/mitre/vulcan/blob/master/docs-old/k8s/k8s-vulcan-deployment-example.yaml)
- [k8s-vulcan-config-example.yml](https://github.com/mitre/vulcan/blob/master/docs-old/k8s/k8s-vulcan-config-example.yml)
- [k8s-vulcan-secrets-example.yaml](https://github.com/mitre/vulcan/blob/master/docs-old/k8s/k8s-vulcan-secrets-example.yaml)
- [k8s-vulcan-ingress-example.yaml](https://github.com/mitre/vulcan/blob/master/docs-old/k8s/k8s-vulcan-nginx-ingress-example.yaml)

## Next Steps

- [Docker Deployment](docker.md) - Container basics
- [Environment Variables](../getting-started/environment-variables.md) - Full configuration reference
- [Authentication Setup](auth/oidc-okta.md) - Configure SSO