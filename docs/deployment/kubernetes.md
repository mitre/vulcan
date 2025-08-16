# Kubernetes Deployment

## Overview

Vulcan can be deployed to Kubernetes using the provided example manifests. This guide covers deployment, configuration, and best practices for running Vulcan in a Kubernetes environment.

## Prerequisites

- Kubernetes cluster (1.21+)
- kubectl configured
- PostgreSQL database (can be in-cluster or external)
- Ingress controller (nginx recommended)

## Quick Start

### 1. Create Namespace

```bash
kubectl create namespace vulcan
```

### 2. Configure Secrets

Create a secret with your configuration:

```yaml
# k8s-vulcan-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: vulcan-secrets
  namespace: vulcan
type: Opaque
stringData:
  DATABASE_URL: "postgresql://user:pass@postgres:5432/vulcan"
  SECRET_KEY_BASE: "your-secret-key-base"
  VULCAN_OIDC_CLIENT_SECRET: "your-oidc-secret"
```

Apply the secret:
```bash
kubectl apply -f k8s-vulcan-secrets.yaml
```

### 3. Deploy Vulcan

```yaml
# k8s-vulcan-deployment.yaml
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
      automountServiceAccountToken: false  # Security best practice
      containers:
      - name: vulcan
        image: mitre/vulcan:v2.2.1
        ports:
        - containerPort: 3000
        envFrom:
        - secretRef:
            name: vulcan-secrets
        - configMapRef:
            name: vulcan-config
        env:
        - name: RAILS_ENV
          value: production
        - name: RAILS_LOG_TO_STDOUT
          value: "true"
        - name: RAILS_SERVE_STATIC_FILES
          value: "true"
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
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
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
            image: postgres:15
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