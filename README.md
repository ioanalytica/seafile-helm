# Seafile Helm Chart

A Helm chart for deploying [Seafile](https://www.seafile.com/) on Kubernetes. Supports both **Community Edition (CE)** and **Professional Edition (Pro)** via a single chart, controlled by `seafile.edition`.

## Prerequisites

- Kubernetes 1.24+
- Helm 3+
- An external **MySQL/MariaDB** database
- An external **Redis** (recommended) or Memcached instance
- For Pro edition: a valid Seafile license file

## Quick Start

### Install from OCI Registry

```bash
helm install seafile oci://ghcr.io/ioanalytica/charts/seafile \
  --namespace seafile --create-namespace \
  -f values.yaml
```

### Upgrade

```bash
helm upgrade seafile oci://ghcr.io/ioanalytica/charts/seafile \
  --namespace seafile \
  -f values.yaml
```

## Initialization Workflow

Seafile requires a two-step deployment:

1. **First deploy** with `seafile.initMode: true` - creates databases, admin user, and initial config
2. **Set `seafile.initMode: false`** and upgrade - switches to normal operation

```bash
# Step 1: Initial deployment
helm install seafile seafile/seafile -n seafile -f values.yaml

# Step 2: After Seafile is running, disable init mode
# Edit values.yaml: set seafile.initMode to false
helm upgrade seafile seafile/seafile -n seafile -f values.yaml
```

## Migrating an Existing Installation

If you have an existing Seafile instance (Docker Compose, manual install, or the official Helm chart), you can migrate it to this chart. The key rule: **always use `initMode: false`** — your databases, config files, and data already exist.

### Prerequisites

Before migrating, gather the following from your current installation:

1. **Database credentials** — host, port, user, password, and the three database names (`ccnet_db`, `seafile_db`, `seahub_db`)
2. **JWT private key** — from `seafile.conf` under `[notification]` → `jwt_private_key`
3. **Cache configuration** — Redis or Memcached host, port, and password
4. **Storage** — if using S3: endpoint, buckets, access key, and secret key
5. **LDAP settings** — if applicable: server URL, base DN, admin DN, password, filters, sync options
6. **License file** — for Pro edition
7. **The PVC or data directory** — containing `/shared/seafile/`

### Steps

1. **Make the existing data volume available** as a PVC in your Kubernetes cluster. Use `persistence.existingClaim` to reference it:

   ```yaml
   seafile:
     persistence:
       existingClaim: "my-existing-seafile-data"
   ```

2. **Create the Kubernetes Secret** with your existing credentials:

   ```bash
   kubectl create secret generic seafile-secret -n seafile \
     --from-literal=JWT_PRIVATE_KEY='<from seafile.conf>' \
     --from-literal=SEAFILE_MYSQL_DB_PASSWORD='<your db password>' \
     --from-literal=REDIS_PASSWORD='<your redis password>'
   ```

3. **Prepare your `values.yaml`** with all settings matching your current installation:

   ```yaml
   seafile:
     edition: "pro"              # or "ce"
     initMode: false             # critical — do NOT run init on an existing installation

     existingSecret: "seafile-secret"

     server:
       hostname: "seafile.example.com"
       protocol: "https"
       timezone: "Europe/Berlin"

     database:
       host: "mariadb.example.com"
       user: "seafile"
       # password comes from existingSecret

     cache:
       provider: "redis"
       redis:
         host: "redis.example.com"
         existingSecret: "redis-credentials"
         existingSecretKey: "redis-password"

     persistence:
       existingClaim: "my-existing-seafile-data"

     # If using S3 storage:
     # storage:
     #   type: "s3"
     #   s3:
     #     host: "s3.example.com"
     #     commitBucket: "seafile-commit"
     #     fsBucket: "seafile-fs"
     #     blockBucket: "seafile-block"
     #     keyId: "your-access-key"
     #     pathStyleRequest: true    # for MinIO

     seahub:
       debug: false
       # rawConfig for any additional seahub_settings.py settings
       # that were in your original installation
   ```

4. **If using LDAP**, create the LDAP ConfigMap with your existing settings (excluding `ENABLE_LDAP` and `LDAP_ADMIN_PASSWORD` — the chart manages those) and add `LDAP_ADMIN_PASSWORD` to your secret.

5. **If using Pro edition**, create the license secret:

   ```bash
   kubectl create secret generic seafile-license -n seafile \
     --from-file=seafile-license.txt=/path/to/your/license
   ```

6. **Deploy**:

   ```bash
   helm install seafile oci://ghcr.io/ioanalytica/charts/seafile \
     --namespace seafile -f values.yaml
   ```

7. **Verify** that the init container patches the config files correctly. The [Configuration Sync](#configuration-sync) mechanism will update `ccnet.conf`, `seafile.conf`, `seafevents.conf`, and `seahub_settings.py` to match your chart values. Check the pod logs:

   ```bash
   kubectl logs deploy/seafile -c configure -n seafile
   ```

### Important Notes

- **Never use `initMode: true`** on an existing installation — it would attempt to re-create databases and overwrite your admin account.
- The chart's [Configuration Sync](#configuration-sync) will patch your existing config files on the PVC to match the chart values. This is the desired behaviour — it ensures the config files stay in sync going forward.
- Any custom settings in `seahub_settings.py` that are not covered by chart values should be added via `seahub.rawConfig` or an LDAP ConfigMap. The chart **replaces** `seahub_settings.py` on every start.
- After the first successful start, verify your settings by inspecting the config files on the PVC.

## Configuration Sync

A key difference between this chart and all other Seafile deployment methods (Docker Compose, manual install, the official Helm chart): **configuration files on the PVC are kept in sync with chart values on every pod start.**

In a standard Seafile deployment, environment variables and settings are only used during the initial setup to generate config files (`ccnet.conf`, `seafile.conf`, `seafevents.conf`, `seahub_settings.py`). After init, these files on the PVC take precedence and are never updated — changing an environment variable or Helm value has no effect.

This chart solves that problem. An init container runs on every pod start and:

- **`seahub_settings.py`** — fully generated from chart values (`database`, `cache`, `seahub.debug`, `server.hostname`, LDAP, etc.) and written to the PVC, replacing any previous version
- **`ccnet.conf`** — patches `HOST`, `PORT`, `USER`, `PASSWD`, and `DB` in the `[Database]` section
- **`seafile.conf`** — patches `host`, `port`, `user`, `password`, and `name` in the `[database]` section, and `jwt_private_key` in the `[notification]` section
- **`seafevents.conf`** — patches `host`, `port`, `username`, `password`, and `name` in the `[DATABASE]` section

This means you can change database credentials, cache provider, JWT key, LDAP settings, or any other chart value and simply restart the pod — the config files will be updated automatically.

## Flux CD

### Stable (from OCI registry)

```yaml
# HelmRepository (shared across all ioanalytica charts)
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: ioanalytica-public
  namespace: flux-system
spec:
  type: oci
  interval: 30m
  url: oci://ghcr.io/ioanalytica/charts
---
# HelmRelease
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: seafile
  namespace: seafile
spec:
  interval: 1h
  chart:
    spec:
      chart: seafile
      version: "13.0.19-12"
      sourceRef:
        kind: HelmRepository
        name: ioanalytica-public
        namespace: flux-system
  values:
    seafile:
      # ... your values here
```

### Development (from Git)

Pull the chart directly from the `develop` branch:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: seafile-dev
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/ioanalytica/seafile-helm
  ref:
    branch: develop
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: seafile
  namespace: seafile
spec:
  interval: 1m
  chart:
    spec:
      chart: .
      sourceRef:
        kind: GitRepository
        name: seafile-dev
        namespace: flux-system
  values:
    seafile:
      # ... your values here
```

## Secrets Management

### Chart-managed Secret

For quick testing, set passwords directly in `values.yaml`. The chart creates a Secret named `seafile-secret`:

```yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: seafile-secret
stringData:
  JWT_PRIVATE_KEY: ""
  SEAFILE_MYSQL_DB_PASSWORD: ""
  INIT_SEAFILE_ADMIN_PASSWORD: ""         # only when initMode is true
  INIT_SEAFILE_MYSQL_ROOT_PASSWORD: ""    # only when initMode is true
  REDIS_PASSWORD: ""                      # when cache.provider is redis
  # MEMCACHED_PASSWORD: ""               # when cache.provider is memcached
  # S3_SECRET_KEY: ""                    # pro edition with storage.type s3
  # S3_SSE_C_KEY: ""                     # pro edition with storage.type s3
  # LDAP_ADMIN_PASSWORD: ""              # pro edition with seahub.ldap.enabled
```

### External Secret (recommended for production)

Create the secret manually and reference it. This keeps passwords out of Helm release metadata:

```bash
kubectl create secret generic seafile-secret -n seafile \
  --from-literal=JWT_PRIVATE_KEY='your-jwt-key' \
  --from-literal=SEAFILE_MYSQL_DB_PASSWORD='dbpass' \
  --from-literal=INIT_SEAFILE_ADMIN_PASSWORD='adminpass' \
  --from-literal=INIT_SEAFILE_MYSQL_ROOT_PASSWORD='rootpass'
```

```yaml
seafile:
  existingSecret: "seafile-secret"
```

**Expected keys in the external secret:**

| Key | Required |
|-----|----------|
| `JWT_PRIVATE_KEY` | Always |
| `SEAFILE_MYSQL_DB_PASSWORD` | Always |
| `INIT_SEAFILE_ADMIN_PASSWORD` | When `initMode: true` |
| `INIT_SEAFILE_MYSQL_ROOT_PASSWORD` | When `initMode: true` |
| `REDIS_PASSWORD` | When `cache.provider: redis` (unless `cache.redis.existingSecret` is set) |
| `MEMCACHED_PASSWORD` | When `cache.provider: memcached` (unless `cache.memcached.existingSecret` is set) |
| `S3_SECRET_KEY` | When `edition: pro` and `storage.type: s3` |
| `S3_SSE_C_KEY` | When `edition: pro` and `storage.type: s3` |
| `LDAP_ADMIN_PASSWORD` | When `edition: pro` and `seahub.ldap.enabled: true` |

Cache passwords can also come from a separate secret per provider:

```yaml
seafile:
  cache:
    redis:
      existingSecret: "redis-credentials"
      existingSecretKey: "redis-password"
```

## License (Pro Edition)

For Pro edition, mount the license file from a Secret:

```bash
kubectl create secret generic seafile-license -n seafile \
  --from-file=seafile-license.txt=/path/to/your/license
```

```yaml
seafile:
  edition: "pro"
  license:
    existingSecret: "seafile-license"
```

Without a license, Pro edition runs in trial mode (max 3 users).

## LDAP (Pro Edition)

LDAP settings are provided via an external ConfigMap. The chart handles `ENABLE_LDAP` and `LDAP_ADMIN_PASSWORD` automatically.

1. Create a ConfigMap with your LDAP settings:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: seafile-ldap
  namespace: seafile
data:
  ldap_settings.py: |
    LDAP_SERVER_URL = 'ldaps://ldap.example.com:636/'
    LDAP_BASE_DN = 'dc=example,dc=com'
    LDAP_ADMIN_DN = 'cn=admin,dc=example,dc=com'
    LDAP_LOGIN_ATTR = 'uid'
    LDAP_FILTER = 'memberOf=cn=seafile,ou=groups,dc=example,dc=com'
    ENABLE_LDAP_USER_SYNC = True
    LDAP_SYNC_INTERVAL = 60
```

2. Reference it in values:

```yaml
seafile:
  seahub:
    ldap:
      enabled: true
      configMap: "seafile-ldap"
```

3. Add `LDAP_ADMIN_PASSWORD` to your existing secret.

**Do not** include `ENABLE_LDAP` or `LDAP_ADMIN_PASSWORD` in the ConfigMap - the chart manages those.

## Seahub Settings

As described in [Configuration Sync](#configuration-sync), the chart generates `seahub_settings.py` from your values and writes it to the PVC on every pod start. This includes `DATABASES`, `CACHES`, `SERVICE_URL`, `CSRF_TRUSTED_ORIGINS`, `DEBUG`, and timezone settings. Passwords are read from environment variables at runtime via `os.environ.get()` — they never appear in the ConfigMap.

For additional Seahub settings, use `rawConfig`:

```yaml
seafile:
  seahub:
    debug: false
    rawConfig: |
      ENABLE_SIGNUP = False
      LOGIN_REMEMBER_DAYS = 7
      USER_PASSWORD_MIN_LENGTH = 10
```

## Logging

By default, the chart mounts an `emptyDir` over `/shared/seafile/logs` to prevent log files from accumulating on the PVC. Logs are ephemeral and go to stdout (for collection by Promtail, Loki, or similar).

To disable this and keep logs on the PVC:

```yaml
seafile:
  logging:
    ephemeral: false
```

## Values Reference

### General

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.edition` | `"ce"` or `"pro"` | `"ce"` |
| `seafile.initMode` | Enable initialization mode for first deployment | `true` |
| `seafile.image.repository` | Override image repository (defaults to `seafileltd/seafile-mc` for CE, `seafileltd/seafile-pro-mc` for Pro) | `""` |
| `seafile.image.tag` | Override image tag (defaults to `appVersion`) | `""` |
| `seafile.existingSecret` | Name of pre-created Secret | `""` |
| `seafile.imagePullSecrets` | Image pull secrets | `[]` |
| `seafile.nodeSelector` | Node selector for pod scheduling | `{}` |
| `seafile.tolerations` | Tolerations for pod scheduling | `[]` |
| `seafile.resources` | Container resource requests/limits | `{}` |
| `seafile.extraEnv` | Extra env sources (configMapRef/secretRef) | `[]` |
| `seafile.extraVolumes` | Extra volumes | `[]` |
| `seafile.extraVolumeMounts` | Extra volume mounts | `[]` |

### Service

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.service.type` | Service type | `"ClusterIP"` |
| `seafile.service.loadBalancerIP` | Static LB IP (when type is LoadBalancer) | - |

### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.ingress.enabled` | Enable ingress | `false` |
| `seafile.ingress.ingressClassName` | Ingress class | `""` |
| `seafile.ingress.annotations` | Ingress annotations | `{}` |
| `seafile.ingress.hosts` | Ingress host rules | see values.yaml |
| `seafile.ingress.tls` | TLS configuration | `[]` |

### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.persistence.enabled` | Enable persistent storage | `true` |
| `seafile.persistence.storageClassName` | Storage class | `""` |
| `seafile.persistence.accessMode` | PVC access mode | `"ReadWriteOnce"` |
| `seafile.persistence.size` | PVC size | `"10Gi"` |
| `seafile.persistence.existingClaim` | Use an existing PVC | `""` |

### Server

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.server.hostname` | **Required.** Server hostname | `""` |
| `seafile.server.protocol` | `"http"` or `"https"` | `"https"` |
| `seafile.server.siteRoot` | Site root path | `"/"` |
| `seafile.server.timezone` | Timezone | `"UTC"` |
| `seafile.server.logToStdout` | Log to stdout | `true` |

### Logging

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.logging.ephemeral` | Mount emptyDir over logs directory | `true` |

### Admin

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.admin.email` | Admin email (required when `initMode: true`) | `""` |
| `seafile.admin.password` | Admin password (use `existingSecret` for production) | `""` |

### Database

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.database.mode` | `"internal"` (chart deploys MariaDB) or `"external"` (provide host) | `"external"` |
| `seafile.database.host` | **Required when mode is external.** Database host | `""` |
| `seafile.database.port` | Database port | `3306` |
| `seafile.database.user` | Database user | `"seafile"` |
| `seafile.database.password` | Database password (use `existingSecret` for production) | `""` |
| `seafile.database.rootPassword` | Root password for init (use `existingSecret` for production) | `""` |
| `seafile.database.ccnetDbName` | Ccnet database name | `"ccnet_db"` |
| `seafile.database.seafileDbName` | Seafile database name | `"seafile_db"` |
| `seafile.database.seahubDbName` | Seahub database name | `"seahub_db"` |

### Cache

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.cache.mode` | `"internal"` (chart deploys Redis) or `"external"` (provide host). When `internal`, `existingSecret` and `host` settings are ignored. | `"external"` |
| `seafile.cache.provider` | `"redis"` or `"memcached"` | `"redis"` |
| `seafile.cache.redis.host` | Redis host (required when mode is external and provider is redis) | `""` |
| `seafile.cache.redis.port` | Redis port | `6379` |
| `seafile.cache.redis.password` | Redis password (use `existingSecret` for production) | `""` |
| `seafile.cache.redis.existingSecret` | Existing secret for Redis password | `""` |
| `seafile.cache.redis.existingSecretKey` | Key in the existing secret | `"redis-password"` |
| `seafile.cache.memcached.host` | Memcached host | `""` |
| `seafile.cache.memcached.port` | Memcached port | `11211` |
| `seafile.cache.memcached.password` | Memcached password | `""` |
| `seafile.cache.memcached.existingSecret` | Existing secret for Memcached password | `""` |
| `seafile.cache.memcached.existingSecretKey` | Key in the existing secret | `"memcached-password"` |

### Storage (Pro edition)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.storage.type` | `"disk"` or `"s3"` | `"disk"` |
| `seafile.storage.s3.commitBucket` | S3 commit bucket | `""` |
| `seafile.storage.s3.fsBucket` | S3 filesystem bucket | `""` |
| `seafile.storage.s3.blockBucket` | S3 block bucket | `""` |
| `seafile.storage.s3.keyId` | S3 access key ID | `""` |
| `seafile.storage.s3.secretKey` | S3 secret key (use `existingSecret` for production) | `""` |
| `seafile.storage.s3.sseCKey` | S3 SSE-C encryption key | `""` |
| `seafile.storage.s3.useV4Signature` | Use AWS V4 signatures | `true` |
| `seafile.storage.s3.region` | S3 region | `"us-east-1"` |
| `seafile.storage.s3.host` | S3 endpoint (for S3-compatible services like MinIO) | `""` |
| `seafile.storage.s3.useHttps` | Use HTTPS for S3 | `true` |
| `seafile.storage.s3.pathStyleRequest` | Use path-style requests (required for MinIO) | `false` |

### JWT

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.jwt.privateKey` | JWT private key (use `existingSecret` for production) | `""` |

### Features

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.notification.enabled` | Enable notification server | `false` |
| `seafile.notification.url` | Notification server URL (required when enabled) | `""` |
| `seafile.seadoc.enabled` | Enable SeaDoc | `false` |
| `seafile.seadoc.url` | SeaDoc server URL (required when enabled) | `""` |
| `seafile.ai.enabled` | Enable Seafile AI | `false` |
| `seafile.ai.url` | AI server URL (required when enabled) | `""` |
| `seafile.metadata.fileCountLimit` | Metadata file count limit | `100000` |

### License (Pro edition)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.license.existingSecret` | Secret containing the license file | `""` |
| `seafile.license.secretKey` | Key within the secret | `"seafile-license.txt"` |

### Seahub

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.seahub.debug` | Enable Django debug mode | `false` |
| `seafile.seahub.ldap.enabled` | Enable LDAP (Pro only) | `false` |
| `seafile.seahub.ldap.configMap` | ConfigMap with LDAP settings | `""` |
| `seafile.seahub.ldap.configMapKey` | Key within the ConfigMap | `"ldap_settings.py"` |
| `seafile.seahub.ldap.adminPassword` | LDAP admin password (use `existingSecret` for production) | `""` |
| `seafile.seahub.rawConfig` | Raw Python to append to seahub_settings.py | `""` |

### Elasticsearch

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.elasticsearch.enabled` | Enable Elasticsearch for full-text search | `false` |
| `seafile.elasticsearch.mode` | `"internal"` or `"external"` | `"external"` |
| `seafile.elasticsearch.host` | ES host (required when mode is external) | `""` |
| `seafile.elasticsearch.port` | ES port | `9200` |
| `seafile.elasticsearch.username` | ES username (external with auth) | `""` |
| `seafile.elasticsearch.password` | ES password (use `existingSecret` key `ES_PASSWORD`) | `""` |
| `seafile.elasticsearch.internal.image` | Image for internal ES | `"elasticsearch:8.15.0"` |
| `seafile.elasticsearch.internal.javaOpts` | JVM options | `"-Xms512m -Xmx512m"` |
| `seafile.elasticsearch.internal.storageSize` | PVC size | `"5Gi"` |

### Cluster

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seafile.cluster.enabled` | Enable cluster mode (frontend/backend split) | `false` |
| `seafile.cluster.initMode` | Override cluster init independently of `initMode`. Use `true` when migrating from single to cluster. | `""` (follows `initMode`) |
| `seafile.cluster.frontend.replicas` | Number of frontend replicas (0 during cluster init) | `2` |

## Cluster Mode

Cluster mode splits Seafile into two deployments:

- **Backend** (`<release>-backend`, 1 replica) — handles background tasks: email notifications, maintenance jobs, search indexing. Always a single instance.
- **Frontend** (`<release>-frontend`, scalable) — serves the web UI via Seahub. Can be scaled horizontally for HA.

### Requirements

- **Pro edition** recommended (CE works but has limited cluster features)
- **Elasticsearch** must be enabled (`elasticsearch.enabled: true`) — the chart will fail validation otherwise
- **ReadWriteMany PVC** — the chart automatically forces `ReadWriteMany` access mode when cluster is enabled, since both backend and frontend pods mount the same volume
- **External or shared cache** — all pods must share the same Redis/Memcached instance. When using `cache.mode: external`, point it at a shared Redis (e.g., Dragonfly, Redis Sentinel, or a dedicated Redis deployment). When using `cache.mode: internal`, the chart deploys a single Redis pod that all Seafile pods connect to.

### How It Works

When `cluster.enabled: true`, the chart:

1. **Creates two Deployments** instead of one:
   - `<release>-backend` with `CLUSTER_MODE=backend`
   - `<release>-frontend` with `CLUSTER_MODE=frontend`
   - Both receive `CLUSTER_SERVER=true` and `CLUSTER_INIT_MODE=<true|false>`

2. **Adds `[cluster] enable = true`** to `seafile.conf` — both in the ConfigMap template (for fresh generation) and via `ensure_ini` in the patch path (for existing files). This section is only present when cluster mode is enabled.

3. **Routes the Service** (`<release>-seafile`) exclusively to frontend pods. The backend has no exposed ports — it communicates only with the database, cache, and Elasticsearch.

4. **Scales frontend replicas** to `cluster.frontend.replicas` (default: 2). During cluster init, frontend replicas are held at 0 so only the backend runs.

5. **Shares the PVC** across all pods. Both deployments mount the same persistent volume, which is why `ReadWriteMany` is required.

### Init Workflow (Fresh Install)

1. Deploy with `initMode: true` — only the backend pod starts (frontend replicas = 0)
2. Wait for initialization to complete
3. Set `initMode: false` and upgrade — frontend pods scale up to the configured replica count

```yaml
seafile:
  edition: "pro"
  initMode: false

  elasticsearch:
    enabled: true
    mode: internal

  cluster:
    enabled: true
    frontend:
      replicas: 3
```

### Configuration Sync in Cluster Mode

The same [Configuration Sync](#configuration-sync) mechanism applies to both backend and frontend pods. Each deployment has its own `configure` init container that:

- Generates missing config files from templates (first run)
- Ensures required sections exist — including `[cluster]`, `[database]`, and `[notification]` in `seafile.conf`
- Patches existing config files with current values from the chart

Since both pods share the same PVC, the init containers operate on the same config files. This is safe because they perform identical operations.

### Migrating an Existing Instance to Cluster Mode

If you have an existing single-instance Seafile Pro deployment and want to enable cluster mode:

1. **Prepare a ReadWriteMany PVC.** You cannot change the access mode of an existing PVC in-place. Your options:

   - If your storage class already supports RWX (NFS, CephFS, etc.), create a new PVC with `ReadWriteMany`, copy the data from the old PVC, and update `persistence.existingClaim`.
   - If you're on block storage (Longhorn RWO, EBS, etc.), you need to migrate to a shared filesystem first.
   - If using the chart-managed PVC (not `existingClaim`), delete the old PVC and let the chart create a new one with the correct access mode, then restore data from a backup.

2. **Enable Elasticsearch.** Cluster mode requires it. Use internal mode for simplicity:

   ```yaml
   seafile:
     elasticsearch:
       enabled: true
       mode: internal
   ```

   The `[INDEX FILES]` section in `seafevents.conf` will be created by Seafile's init process when it detects the Elasticsearch environment variables. If the section already exists, the init container patches `es_host` and `es_port` to match the chart values.

3. **Enable cluster mode with `cluster.initMode: true`** but keep `initMode: false` — your databases exist, but cluster/ES config needs initialization:

   ```yaml
   seafile:
     edition: "pro"
     initMode: false         # databases exist — do NOT re-init

     elasticsearch:
       enabled: true
       mode: internal

     cluster:
       enabled: true
       initMode: true        # initialize ES indices and cluster config
       frontend:
         replicas: 2

     persistence:
       existingClaim: "my-rwx-seafile-data"
   ```

   `cluster.initMode` is independent of `initMode`. When set to `true`, it tells Seafile to create Elasticsearch indices and cluster-specific configuration, and keeps frontend replicas at 0 during this phase. When left empty (default), it follows `initMode`.

4. **Deploy.** Only the backend starts (`CLUSTER_INIT_MODE=true`, frontend replicas = 0). The backend initializes ES indices and cluster config.

5. **Set `cluster.initMode: false`** (or remove it) and upgrade — frontend pods scale up:

   ```yaml
   cluster:
     enabled: true
     # initMode removed — defaults to following initMode (false)
     frontend:
       replicas: 2
   ```

6. **Verify** by checking the pod logs:

   ```bash
   kubectl logs deploy/seafile-backend -c configure -n seafile
   kubectl logs deploy/seafile-frontend -c configure -n seafile
   ```

**Important:** Never use `initMode: true` when migrating — it would attempt to re-create databases and overwrite your admin account. Use `cluster.initMode: true` instead for the cluster-specific initialization.

### Disabling Cluster Mode

To go back to a single-instance deployment, set `cluster.enabled: false`. The chart will:

- Create a single deployment (`<release>-seafile`) instead of backend/frontend
- Remove the `[cluster]` section from `seafile.conf` (on next fresh generation)
- Stop setting `CLUSTER_SERVER`, `CLUSTER_MODE`, and `CLUSTER_INIT_MODE` environment variables

Note that you may also need to switch your PVC back to `ReadWriteOnce` if your storage class does not support `ReadWriteMany`.

### Troubleshooting

**Config files missing sections after switching from init to normal mode:**
During `initMode`, Seafile's own init process creates minimal config files (e.g., `seafile.conf` with only `[fileserver]` and `[cluster]`). When you disable `initMode`, the chart's `configure` init container detects the existing file and uses `ensure_ini` to add any missing sections (`[database]`, `[notification]`, `[cluster]`) before patching values. Check the init container logs to confirm sections were added:

```bash
kubectl logs deploy/seafile-backend -c configure -n seafile
```

**Redis AuthenticationError (`invalid username-password pair`):**
Verify that `cache.mode` matches your setup. If you use an external Redis (e.g., Dragonfly), set `cache.mode: external` — not `internal`. When `mode: internal`, the chart deploys its own Redis pod and ignores `existingSecret` / `host` settings. See [Cache](#cache) for details.

## Examples

See the [`examples/`](examples/) directory:

- `helmrepository.yaml` - Flux HelmRepository resource (OCI)
- `helmrelease.yaml` - Flux HelmRelease for stable releases
- `helmrelease-dev.yaml` - Flux HelmRelease for development (from Git)
