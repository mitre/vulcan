# vulcan-k8s-example-deployment
These example files are to help deploy the [Vulcan STIG Development](https://github.com/mitre/vulcan) tool in Kubernetes.  

The examples will need to be tweaked to fit your environment and Kubernetes capabilities.  

## Requirements
- A K8s namespace and storage for a PVC for PostgreSQL
- kubectl and kubeconfig for connecting to the cluster
- helm 3.6.3+
- The bitnami/postgresql helm chart is used for this example.

## Installation

### Setup Secrets

First some secrets must be setup that PostgreSQL and Vulcan will need to operate. 

These can be done through secrets in k8s or another vault option.  

1. Download vulcan by running `git clone https://github.com/mitre/vulcan.git`.
2. Run the following commands to generate secrets and apply them to your k8s namespace
    1. `./setup-docker-secrets.sh`
    2. Collect generated values from the .env and .env-prod files
    3. Update the k8s-vulcan-secrets-example.yaml with the collected values and LDAP service account credentials if required
    4. `kubectl apply -f /path/to/k8s-vulcan-secrets-example.yaml`
 
### PostgreSQL Installation Example
 
1. Install bitnami/postgresql helm chart by running `helm repo add bitnami https://charts.bitnami.com/bitnami`
2. Create and update a values.yaml for PostgreSQL with your environments requirements
3. Deploy PostgreSQL via helm chart with custom values by running `helm --kubeconfig /path/to/kubeconfig install postgresql -f /path/to/postgresql-helm-values.yaml bitnami/postgresql`

### Vulcan Installation

Vulcan is currently available for installation through a docker-compose file so we are adapting that to Kubernetes.  

1. Fill out the example config for Vulcan or support properties via env variables in the deployment file
    1. Create a configmap for the vulcan.yml config file in k8s
    2. `kubectl create configmap vulcan-config --from-file /path/to/k8s-vulcan-config-example.yml`
2. Update the k8s-vulcan-deployment-example.yaml for your environment
3. Deploy Vulcan to your k8s namespace
    1. `kubectl apply -f /path/to/k8s-vulcan-deployment-example.yaml`
    2. *Steps below are for initial deployment only*
    3. Exec into the vulcan container `kubectl exec -it vulcan-web-0 -- /bin/bash`
    4. Run `rake db:schema:load db:migrate` *this assumes the database is already created in PostgreSQL*
    5. If DB is not present run `rake db:create db:schema:load db:migrate`
    6. Run `rake db:create_admin`

Note: The last command will create the initial admin account for Vulcan.

### Ingress Setup

Ingress will vary by k8s deployment. In this example there is a shared nginx ingress already setup.  

1. Create or update the example ingress manifest file for your environment
2. Apply the manifest by running `kubectl apply -f /path/to/vulcan-nginx-ingress.yaml` 

## Update Vulcan

1. To update to a new container image assuming the latest tag is in use run `kubectl rollout restart deployment vulcan-web`
2. You can also just delete the pods and they will redeploy.  

## Backup/Restore Vulcan

In this example we are creating a k8s cron job to create backups of the PostgreSQL database daily and store them on a separate persistent volume.

To setup the cron job:  

1. Determine what your persistent volume claim will be for your backups
2. Update k8s-vulcan-cron-postgres-backup-example.yaml for your environment
3. Apply the cron job manifest by running `kubectl apply -f /path/to/k8s-vulcan-cron-postgres-backup-example.yaml`
4. You can view job runs by running `kubectl get all -o wide` or `kubectl get jobs`
5. *Optional* You can copy a backup off a running container with the PVC by running:
    1. `kubectl cp postgresql-postgresql-0:path/to/backup/vulcan-db-backup.sql /local/path/vulcan-db-backup.sql`

To restore from a pg_dump .sql file to a db with data already in it:  

1. Copy the backup to the PostgreSQL container if needed `kubectl cp /local/path/vulcan-db-backup.sql postgresql-postgresql-0:path/to/backup/vulcan-db-backup.sql`
2. Exec into the PostgreSQL Container `kubectl exec -it postgresql-postgresql-0 -- /bin/bash`
3. Drop and recreate the database
    1. `psql -U postgres`
    2. `drop database vulcan_postgres_production;`
    3. `create database vulcan_postgres_production;`
    4. `quit`
    5. `psql -U postgres vulcan_postgres_production < vulcan-db-backup.sql`

To restore from a pg_dump .sql file to a new PostgreSQL deployment with an empty existing database:  

1. Copy the backup to the PostgreSQL container if needed `kubectl cp /local/path/vulcan-db-backup.sql postgresql-postgresql-0:path/to/backup/vulcan-db-backup.sql`
2. Exec into the PostgreSQL Container `kubectl exec -it postgresql-postgresql-0 -- /bin/bash`
3. `psql -U postgres vulcan_postgres_production < vulcan-db-backup.sql`

