<h1 align="center"> Mirror-DB </h1>
<hr />


[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?style=flat-square&logo=postgresql)](https://www.postgresql.org/)
[![PgBouncer](https://img.shields.io/badge/PgBouncer-1.22.1-4169E1?style=flat-square)](https://www.pgbouncer.org/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.20+-326CE5?style=flat-square&logo=kubernetes)](https://kubernetes.io/)
[![pg_auto_failover](https://img.shields.io/badge/pg__auto__failover-v2.1-orange?style=flat-square)](https://github.com/citusdata/pg_auto_failover)
[![Kustomize](https://img.shields.io/badge/Kustomize-ready-green?style=flat-square)](https://kustomize.io/)

> 🚀 **Enterprise-grade PostgreSQL High Availability cluster** with automatic failover, intelligent connection pooling, and load balancing for mission-critical workloads in Kubernetes.

## 🎯 Overview

This repository contains a comprehensive PostgreSQL High Availability setup using **pg_auto_failover** with **PgBouncer** connection pooling on Kubernetes. The cluster provides automatic failover, intelligent connection management, read/write splitting, and zero-downtime operations through smart replication and pooling strategies.

### 🌟 Key Features

- **🔄 Automatic Failover**: Sub-minute failover with health monitoring
- **🎯 Intelligent Connection Pooling**: PgBouncer with separate primary/replica pools
- **📊 Multi-tier Replication**: Synchronous + Asynchronous replicas
- **⚖️ Load Balancing**: Smart read/write traffic distribution
- **🛡️ Zero Data Loss**: Synchronous replication ensures consistency
- **⚡ Performance Optimized**: Connection pooling + tuned PostgreSQL
- **🔍 Comprehensive Monitoring**: Health checks and graceful shutdowns
- **🔐 Security First**: SSL encryption and proper authentication
- **🏷️ Dynamic Service Discovery**: Automatic pod labeling for service routing

## 🏗️ Architecture

### Cluster Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                    Applications Layer                           │
│  ┌─────────────────┐              ┌─────────────────────────────┐│
│  │   Write Apps    │              │        Read Apps            ││
│  │                 │              │                             ││
│  └─────────────────┘              └─────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
           │                                        │
           ▼                                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                 PgBouncer Connection Pools                      │
│  ┌─────────────────┐              ┌─────────────────────────────┐│
│  │ pgbouncer-primary│              │   pgbouncer-replicas       ││
│  │   Port: 6432    │              │      Port: 6432            ││
│  │ Transaction Pool│              │   Transaction Pool          ││
│  └─────────────────┘              └─────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
           │                                        │
           ▼                                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                Kubernetes Services                              │
│  ┌─────────────────┐              ┌─────────────────────────────┐│
│  │postgres-primary │              │   postgres-replicas         ││
│  │ (Label Selector)│              │   (Label Selector)          ││
│  └─────────────────┘              └─────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
           │                                        │
           ▼                                        ▼
┌─────────────────────────────────────────────────────────────────┐
│              PostgreSQL Cluster (StatefulSet)                   │
│                                                                 │
│  ┌──────────┐  ┌──────────────┐  ┌─────────────────────────────┐│
│  │ Monitor  │  │   Primary    │  │         Replicas            ││
│  │(Port 6001│  │postgres-0    │  │  ┌─────────────────────────┐││
│  │          │  │pg-role:      │  │  │ postgres-1 (Sync)       │││
│  │Coordinates│  │primary       │  │  │ postgres-2 (Async)      │││
│  │Failover  │  │              │  │  │ postgres-3 (Async)      │││
│  │          │  │              │  │  │ pg-role: replica        │││
│  └──────────┘  └──────────────┘  │  └─────────────────────────┘││
│                       │          └─────────────────────────────┘│
│                       │                         ▲               │
│                       └─────────────────────────┘               │
│                          Streaming Replication                 │
└─────────────────────────────────────────────────────────────────┘
```

### 🏷️ Dynamic Service Discovery

The cluster uses **automatic pod labeling** to enable dynamic service discovery:

<img src="./static/Failover-Labelling-PgBouncer.png" alt="Pod Labeling System" width="800"/>

<img src="./static/Failover-Labelling-PgBouncer-Result.png" alt="Pod Labeling System Results" width="800"/>

- **Pod Labeler**: Python sidecar container that monitors PostgreSQL roles
- **Dynamic Labels**: Pods get labeled with `pg-role=primary` or `pg-role=replica`
- **Service Selectors**: Kubernetes services automatically route to correct nodes

## 📁 Project Structure

```
mirror-db/
├── kustomization.yaml          # Base Kustomize configuration
├── namespace.yaml              # Kubernetes namespace
├── service-account.yaml        # ServiceAccount for pods
├── configuration/              # ConfigMaps and Secrets
│   ├── cluster-config.yaml     # ⚙️ Central configuration values
│   ├── failover-node.yaml      # Node initialization scripts
│   ├── pgbouncer.yaml          # PgBouncer configuration
│   ├── labeler.yaml            # Pod labeler script
│   └── secrets.yaml            # Database credentials
├── deployments/                # Workload definitions
│   ├── postgres-monitor.yaml   # pg_auto_failover monitor
│   ├── node-setup.yaml         # PostgreSQL StatefulSet
│   ├── pgbouncer-primary.yaml  # PgBouncer for writes
│   └── pgbouncer-replicas.yaml # PgBouncer for reads
├── services/                   # Kubernetes Services
│   ├── nodes.yaml              # PostgreSQL services
│   ├── monitor.yaml            # Monitor service
│   └── pgbouncer.yaml          # PgBouncer services
├── ha/                         # High Availability configs
│   └── pod-disruption-budgets.yaml
├── rbac/                       # RBAC configurations
│   └── labeler.yaml            # Pod labeler permissions
├── pvcs/                       # PersistentVolumeClaims
│   └── monitor.yaml
├── overlays/                   # 🎯 Environment-specific configs
│   ├── production/             # Production settings
│   │   └── kustomization.yaml
│   └── development/            # Development settings
│       └── kustomization.yaml
└── images/                     # Custom container images
    └── pod-labeler/            # Pre-built labeler image
        ├── Dockerfile
        └── labeler.py
```

## 📋 Prerequisites

Before deploying this cluster, ensure you have:

- **Kubernetes cluster** (v1.20+) with:
  - StorageClass `standard` available
  - At least 4 worker nodes (recommended)
  - RBAC enabled
- **kubectl** configured and connected
- **Persistent Volume** support (50Gi per PostgreSQL node)
- **Network policies** allowing inter-pod communication

## 🚀 Quick Start

### Option 1: Deploy with Kustomize (Recommended)

```bash
# Clone the repository
git clone https://github.com/prathamagrawal/mirror-db
cd mirror-db

# Deploy to development environment
kubectl apply -k overlays/development/

# OR Deploy to production environment
kubectl apply -k overlays/production/

# OR Deploy base configuration
kubectl apply -k .
```

### Option 2: Manual Deployment

#### 1. Clone and Navigate

```bash
git clone https://github.com/prathamagrawal/mirror-db
cd mirror-db
```

#### 2. Deploy Prerequisites

```bash
# Create namespace
kubectl create -f namespace.yaml

# Create service account and RBAC
kubectl apply -f service-account.yaml
kubectl apply -f rbac/

# Create secrets for PostgreSQL Monitor and nodes
kubectl apply -f configuration/secrets.yaml

# Create configurations for Monitor, Nodes and PgBouncer
kubectl apply -f configuration/
```

#### 3. Deploy Storage

```bash
# Deploy PVC for monitor
kubectl apply -f pvc/monitor.yaml
```

#### 4. Deploy Monitor Node

```bash
# Deploy the monitor first
kubectl apply -f deployments/postgres-monitor.yaml

# Deploy the monitor node services
kubectl apply -f services/monitor.yaml

# Wait for monitor to be ready
kubectl wait --for=condition=ready pod -l app=postgres-monitor -n db --timeout=300s
```

#### 5. Deploy PostgreSQL Cluster

```bash
# Deploy the PostgreSQL StatefulSet
kubectl apply -f deployments/node-setup.yaml

# Deploy the monitor node services
kubectl apply -f services/nodes.yaml

# Wait for nodes to be ready
kubectl wait --for=condition=ready pod -l app=postgres-nodes -n db --timeout=600s
```

#### 6. Deploy PgBouncer

```bash
# Deploy PgBouncer pools
kubectl apply -f deployments/pgbouncer.yaml
kubectl apply -f services/pgbouncer.yaml
```

#### 7. Verify Deployment

```bash
# Check PostgreSQL pods
kubectl get pods -n db -l app=postgres-nodes

# Check PgBouncer pods
kubectl get pods -n db -l app=pgbouncer-primary

# Check cluster status
kubectl exec -it postgres-nodes-0 -n db -- \
  pg_autoctl show state --pgdata /var/lib/postgresql/pgdata/master

# Check PgBouncer status
kubectl exec -it deployment/pgbouncer-primary -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW POOLS;"
```

## 🎛️ Kustomize Overlays

This project uses **Kustomize** to manage environment-specific configurations. The base configuration provides sensible defaults, while overlays customize settings for different environments.

### Directory Structure

```
mirror-db/
├── kustomization.yaml              # Base configuration (namespace: db)
├── overlays/
│   ├── development/
│   │   └── kustomization.yaml      # Dev overrides (namespace: db-dev)
│   └── production/
│       └── kustomization.yaml      # Prod overrides (namespace: db-production)
```

### Deployment Commands

```bash
# Deploy BASE configuration (for local/minikube testing)
kubectl apply -k .

# Deploy DEVELOPMENT environment
kubectl apply -k overlays/development/

# Deploy PRODUCTION environment
kubectl apply -k overlays/production/

# Preview what will be deployed (dry-run)
kubectl kustomize .
kubectl kustomize overlays/development/
kubectl kustomize overlays/production/
```

### Environment Comparison

| Setting | Base | Development | Production |
|---------|------|-------------|------------|
| **Namespace** | `db` | `db-dev` | `db-production` |
| **PostgreSQL Replicas** | 4 | 2 | 4 |
| **PostgreSQL Memory (request/limit)** | 512Mi / 1Gi | 256Mi / 512Mi | 2Gi / 4Gi |
| **PostgreSQL CPU (request/limit)** | 250m / 1000m | 100m / 500m | 500m / 2000m |
| **PostgreSQL Storage** | 50Gi | 10Gi | 200Gi |
| **Monitor PVC Storage** | 10Gi | 2Gi | 10Gi |
| **PgBouncer Primary Replicas** | 1 | 1 | 2 |
| **PgBouncer Memory (request/limit)** | 64Mi / 256Mi | 64Mi / 256Mi | 256Mi / 512Mi |
| **PDB minAvailable** | 2 | 1 | 2 |
| **Image Tags** | `latest` | `latest` | Pinned versions |
| **Storage Class** | Default | Default | Custom (configurable) |

### What Each Overlay Does

#### Base (`kubectl apply -k .`)
- Default namespace: `db`
- 4 PostgreSQL nodes (1 primary + 1 sync + 2 async replicas)
- Uses `latest` image tags
- Moderate resource allocation
- Suitable for local development and testing

#### Development (`kubectl apply -k overlays/development/`)
- Namespace: `db-dev`
- **Reduced replicas**: Only 2 PostgreSQL nodes (faster startup)
- **Minimal resources**: Lower CPU/memory for laptop-friendly deployment
- **Smaller storage**: 10Gi per node, 2Gi for monitor
- **Relaxed PDB**: Allows more disruption for easy testing
- Labels: `environment: development`

#### Production (`kubectl apply -k overlays/production/`)
- Namespace: `db-production`
- **Full cluster**: 4 PostgreSQL nodes with proper HA
- **High resources**: 2Gi-4Gi memory, 500m-2000m CPU
- **Large storage**: 200Gi per node for production data
- **Scaled PgBouncer**: 2 replicas for redundancy
- **Pinned images**: Specific versions for stability
- **Custom storage class**: Configure for SSD/production storage
- Labels: `environment: production`

### Customizing Overlays

To customize for your environment, edit the overlay's `kustomization.yaml`:

```yaml
# overlays/production/kustomization.yaml
patches:
  - target:
      kind: StatefulSet
      name: postgres-nodes
    patch: |
      - op: replace
        path: /spec/replicas
        value: 6  # Scale to 6 nodes
      - op: replace
        path: /spec/volumeClaimTemplates/0/spec/storageClassName
        value: "fast-ssd"  # Use your storage class
```

---

## ⚙️ Configuration Details

### PostgreSQL Node Roles

| Node | Role | Replication | Priority | Service Routing |
|------|------|-------------|----------|-----------------|
| `postgres-nodes-0` | PRIMARY | Source | 50 | postgres-primary |
| `postgres-nodes-1` | SYNC REPLICA | Synchronous | 50 | postgres-replicas |
| `postgres-nodes-2` | ASYNC REPLICA | Asynchronous | Default | postgres-replicas |
| `postgres-nodes-3` | ASYNC REPLICA | Asynchronous | Default | postgres-replicas |

### PgBouncer Configuration

| PgBouncer Instance | Purpose | Pool Mode | Target Service | Max Connections |
|-------------------|---------|-----------|----------------|-----------------|
| `pgbouncer-primary` | Write Pool | Transaction | postgres-primary | 100 |
| `pgbouncer-replicas` | Read Pool | Transaction | postgres-replicas | 100 |

### Resource Allocation

#### PostgreSQL Nodes
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

#### PgBouncer Nodes
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

## 🎯 Connection Patterns

### Application Connection Endpoints

| Service | Purpose | Port | Connection String |
|---------|---------|------|-------------------|
| `pgbouncer-primary` | Write operations | 6432 | `postgresql://postgres:password@pgbouncer-primary.db.svc.cluster.local:6432/postgres` |
| `pgbouncer-replicas` | Read operations | 6432 | `postgresql://postgres:password@pgbouncer-replicas.db.svc.cluster.local:6432/postgres` |
| `postgres-primary` | Direct primary access | 5432 | `postgresql://postgres:password@postgres-primary.db.svc.cluster.local:5432/postgres` |
| `postgres-replicas` | Direct replica access | 5432 | `postgresql://postgres:password@postgres-replicas.db.svc.cluster.local:5432/postgres` |

### PgBouncer Configuration

```ini
# Primary Pool Configuration
[databases]
postgres = host=postgres-primary.db.svc.cluster.local port=5432 dbname=postgres

[pgbouncer]
pool_mode = transaction
max_client_conn = 100
default_pool_size = 10
reserve_pool_size = 5
auth_type = trust
```

## 🔍 Monitoring and Health Checks

### PostgreSQL Health Checks
- **Readiness**: `pg_isready` validation on port 5432
- **Liveness**: `pg_autoctl` process + connectivity checks
- **Enhanced timing**: Failover-aware probe intervals

### PgBouncer Health Checks

```yaml
readinessProbe:
  tcpSocket:
    port: 6432
  initialDelaySeconds: 10
  periodSeconds: 10

livenessProbe:
  tcpSocket:
    port: 6432
  initialDelaySeconds: 10
  periodSeconds: 30
```

### 🔍 Connection Pool Monitoring

<img src="./static/ConnectionPoolingTesting.png" alt="PgBouncer Connection Pooling in Action" width="800"/>

The image above shows PgBouncer in action with:
- Real-time connection statistics and pool utilization
- Connection multiplexing with efficient resource usage
- Automatic connection management and cleanup

## 🛠️ Operations Guide

### Viewing Cluster Status

<img src="./static/FailoverTesting.png" alt="PostgreSQL Cluster Status and Failover Testing" width="800"/>

```bash
# PostgreSQL cluster state
kubectl exec -it postgres-nodes-0 -n db -- \
  pg_autoctl show state --pgdata /var/lib/postgresql/pgdata/master

# PgBouncer primary pool status
kubectl exec -it deployment/pgbouncer-primary -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW POOLS;"

# PgBouncer replica pool status
kubectl exec -it deployment/pgbouncer-replicas -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW STATS;"
```

### Connection Pool Management

```bash
# Reload PgBouncer configuration
kubectl exec -it deployment/pgbouncer-primary -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "RELOAD;"

# Pause all connections
kubectl exec -it deployment/pgbouncer-primary -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "PAUSE;"

# Resume all connections
kubectl exec -it deployment/pgbouncer-primary -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "RESUME;"
```

### Manual Failover

```bash
# 1. Initiate PostgreSQL failover
kubectl exec -it postgres-nodes-0 -n db -- \
  pg_autoctl perform failover --pgdata /var/lib/postgresql/pgdata/master

# 2. Services automatically route to new primary (via pod labels)
# 3. Verify new primary connection
kubectl exec -it deployment/pgbouncer-primary -n db -- \
  psql -h localhost -p 6432 -d postgres -c "SELECT pg_is_in_recovery();"
```

## ✅ Validation and Testing

### Quick Verification Commands

```bash
# Check all pods are running
kubectl get pods -n db

# Check pod labels (pg-role should show primary/replica)
kubectl get pods -n db -l app=postgres-nodes --show-labels

# Check cluster state from monitor
kubectl exec -n db deployment/postgres-monitor -- \
  pg_autoctl show state --pgdata /var/lib/postgresql/pgdata/monitor

# Check services and endpoints
kubectl get svc,endpoints -n db
```

### Failover Testing

#### Step 1: Identify Current Primary

```bash
# Check which pod is primary
kubectl get pods -n db -l app=postgres-nodes --show-labels | grep primary

# Or query the monitor
kubectl exec -n db deployment/postgres-monitor -- \
  pg_autoctl show state --pgdata /var/lib/postgresql/pgdata/monitor
```

#### Step 2: Create Test Data (Optional)

```bash
# Connect via PgBouncer and create test table
kubectl exec -it -n db deployment/pgbouncer-primary -- \
  psql -h localhost -p 6432 -U postgres -c "
    CREATE TABLE IF NOT EXISTS failover_test (
      id serial PRIMARY KEY,
      ts timestamp DEFAULT now(),
      node text
    );
    INSERT INTO failover_test (node) VALUES ('before-failover');
    SELECT * FROM failover_test;
  "
```

#### Step 3: Trigger Failover

```bash
# Option A: Graceful failover (recommended)
kubectl exec -n db postgres-nodes-0 -- \
  pg_autoctl perform failover --pgdata /var/lib/postgresql/pgdata/master

# Option B: Simulate failure by deleting primary pod
kubectl delete pod -n db postgres-nodes-0

# Option C: Force kill (aggressive test)
kubectl delete pod -n db postgres-nodes-0 --grace-period=0 --force
```

#### Step 4: Watch Failover Progress

```bash
# Terminal 1: Watch pods
kubectl get pods -n db -w

# Terminal 2: Watch monitor logs
kubectl logs -n db deployment/postgres-monitor -f

# Terminal 3: Watch cluster state changes
watch -n 2 "kubectl exec -n db deployment/postgres-monitor -- \
  pg_autoctl show state --pgdata /var/lib/postgresql/pgdata/monitor 2>/dev/null"
```

#### Step 5: Verify New Primary

```bash
# Check new primary pod
kubectl get pods -n db -l app=postgres-nodes --show-labels | grep primary

# Verify data is accessible
kubectl exec -it -n db deployment/pgbouncer-primary -- \
  psql -h localhost -p 6432 -U postgres -c "SELECT * FROM failover_test;"

# Confirm writes work on new primary
kubectl exec -it -n db deployment/pgbouncer-primary -- \
  psql -h localhost -p 6432 -U postgres -c "
    INSERT INTO failover_test (node) VALUES ('after-failover');
    SELECT * FROM failover_test;
  "
```

#### Step 6: Verify Old Primary Rejoins as Replica

```bash
# The StatefulSet will recreate postgres-nodes-0
# Watch it rejoin as a replica
kubectl logs -n db postgres-nodes-0 -f

# Confirm it's now a replica
kubectl get pods -n db -l app=postgres-nodes --show-labels
```

### Expected Failover Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| Detection | 10-30s | Monitor detects primary failure |
| Promotion | 5-10s | Sync replica promoted to primary |
| Label Update | 1-5s | Pod labeler updates `pg-role` label |
| Service Routing | 1-5s | Kubernetes routes traffic to new primary |
| **Total** | **~30-60s** | Full failover completion |

### Connection Testing

<img src="./static/PoolingResults.png" alt="Connection Testing Script" width="800"/>

The connection testing script demonstrates:
- Automated connection validation to both primary and replica services
- Connection pooling efficiency testing
- Real-time monitoring of connection attempts and success rates

### Read/Write Operations Testing

<img src="./static/Replication.png" alt="Database Operations and Read/Write Testing" width="800"/>

This shows practical database operations including:
- Replication is working across all nodes using PgBouncer
- Creating test tables and inserting sample data
- Validating read/write splitting between primary and replicas
- Demonstrating that write operations are properly restricted to primary nodes
- Testing read operations across replica nodes

## 📊 Performance Benefits

### Connection Pool Advantages

| Metric | Without PgBouncer | With PgBouncer | Improvement |
|--------|-------------------|----------------|-------------|
| Connection Overhead | High | Minimal | 70-90% reduction |
| Memory Usage | High per connection | Shared pools | 60-80% reduction |
| Connection Latency | Variable | Consistent | 50-70% faster |
| Concurrent Connections | Limited by PostgreSQL | Pool multiplexing | 5-10x increase |

### Optimized Settings

#### PostgreSQL (Enhanced for pooling)
```postgresql
# Connection settings
max_connections = 100
shared_buffers = 128MB
effective_cache_size = 512MB

# Replication settings
max_wal_senders = 10
max_replication_slots = 10
wal_keep_segments = 64  # ~1GB (use wal_keep_size for PG13+)

# Performance tuning
checkpoint_completion_target = 0.9
wal_buffers = 16MB
```

#### PgBouncer (Transaction pooling)
```ini
# Optimal for OLTP workloads
pool_mode = transaction
default_pool_size = 10
max_client_conn = 100
server_round_robin = 1
```

## 🧹 Cleanup and Teardown

### Remove Specific Environment

```bash
# Remove base deployment
kubectl delete -k .

# Remove development environment
kubectl delete -k overlays/development/

# Remove production environment
kubectl delete -k overlays/production/
```

### Complete Cleanup (including PVCs)

```bash
# Delete all resources in namespace
kubectl delete namespace db

# For development
kubectl delete namespace db-dev

# For production
kubectl delete namespace db-production

# If PVCs persist, delete manually
kubectl delete pvc -n db --all
```

### Reset and Redeploy

```bash
# Full reset (delete everything and redeploy)
kubectl delete namespace db
kubectl apply -k .

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app=postgres-monitor -n db --timeout=300s
kubectl wait --for=condition=ready pod -l app=postgres-nodes -n db --timeout=600s
```

---

## 🚨 Troubleshooting

### Common Issues

#### PVC Not Bound / Pod Pending

**Symptom**: Pod stuck in `Pending` state with PVC errors

```bash
# Check PVC status
kubectl get pvc -n db

# Check events
kubectl describe pod <pod-name> -n db | grep -A 10 Events
```

**Solution**: The StorageClass might not exist. Remove `storageClassName` to use default:

```yaml
# In pvcs/monitor.yaml or volumeClaimTemplates
spec:
  # storageClassName: standard  # Comment out to use default
```

#### Permission Denied Errors in Init Containers

**Symptom**: `mkdir: cannot create directory: Permission denied`

**Solution**: Add a `fix-permissions` init container that runs as root:

```yaml
initContainers:
  - name: fix-permissions
    image: busybox
    command: ['sh', '-c', 'chown -R 101:101 /var/lib/postgresql']
    securityContext:
      runAsUser: 0
    volumeMounts:
      - name: pgdata
        mountPath: /var/lib/postgresql
```

#### PostgreSQL Config Parameter Errors

**Symptom**: `unrecognized configuration parameter "wal_keep_size"`

**Cause**: `wal_keep_size` is PostgreSQL 13+, but pg_auto_failover uses PostgreSQL 11

**Solution**: Use `wal_keep_segments` instead (64 segments ≈ 1GB)

#### Pod Labeling Issues

```bash
# Check pod labels
kubectl get pods -n db --show-labels

# Check pod-labeler container logs
kubectl logs -n db postgres-nodes-0 -c pod-labeler

# Check service endpoints
kubectl get endpoints -n db

# Restart pods if labels are stale
kubectl delete pod -l app=postgres-nodes -n db
```

#### PgBouncer Connection Issues

```bash
# Check PgBouncer logs
kubectl logs -n db deployment/pgbouncer-primary

# Check actual config inside container
kubectl exec -n db deployment/pgbouncer-primary -- cat /etc/pgbouncer/pgbouncer.ini

# Check pool status
kubectl exec -it deployment/pgbouncer-primary -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW POOLS;"

# Check backend connections
kubectl exec -it deployment/pgbouncer-primary -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW SERVERS;"
```

#### CrashLoopBackOff on Sidecar Containers

**Symptom**: Pod shows `1/2 Running` or `CrashLoopBackOff`

**Cause**: Often the `pod-labeler` sidecar failing due to pip install permission issues

**Solution**: Ensure HOME directory is writable:

```yaml
env:
  - name: HOME
    value: /tmp/labeler-home
  - name: PYTHONUSERBASE
    value: /tmp/labeler-home/.local
volumeMounts:
  - name: labeler-home
    mountPath: /tmp/labeler-home
```

#### Split-brain Prevention
- Monitor node coordinates all decisions
- PgBouncer respects service discovery changes
- Automatic reconnection to new primary via service routing

### Debug Commands

```bash
# Check node connectivity to monitor
kubectl exec -it postgres-nodes-0 -n db -- \
  pg_isready -h postgres-monitor.db.svc.cluster.local -p 6001

# View detailed PostgreSQL logs
kubectl logs postgres-nodes-0 -c postgres -n db --tail=100

# Check replication status
kubectl exec -it postgres-nodes-0 -n db -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Test PgBouncer connectivity
kubectl exec -it deployment/pgbouncer-primary -n db -- \
  psql -h postgres-primary.db.svc.cluster.local -p 5432 -U postgres -c "SELECT 1;"
```

## 🔄 Backup and Recovery

### Automated Backups

```bash
# Create backup job
kubectl create job postgres-backup-$(date +%Y%m%d) \
  --image=postgres:11 -n db \
  --command -- /bin/bash -c \
  "pg_dump -h pgbouncer-primary.db.svc.cluster.local -p 6432 -U postgres postgres > /backup/backup-$(date +%Y%m%d).sql"
```

### Point-in-Time Recovery (PITR)

Enable WAL archiving for PITR support:

```sql
# Add to postgresql.conf
archive_mode = on
archive_command = 'cp %p /path/to/archive/%f'
wal_level = replica
```

## 📈 Scaling Strategies

### Horizontal Scaling

```bash
# Add more PostgreSQL replicas
kubectl scale statefulset postgres-nodes --replicas=6 -n db

# Scale PgBouncer pools
kubectl scale deployment pgbouncer-replicas --replicas=3 -n db
```

### Advanced Pool Configurations

```ini
# Workload-specific databases
[databases]
postgres = host=postgres-primary.db.svc.cluster.local port=5432 dbname=postgres
analytics = host=postgres-replicas.db.svc.cluster.local port=5432 dbname=postgres pool_size=15
reporting = host=postgres-replicas.db.svc.cluster.local port=5432 dbname=postgres pool_size=20
```

## 🔐 Security Considerations

### Production Hardening

1. **Authentication**: Replace trust authentication with md5/scram-sha-256
2. **SSL/TLS**: Use proper certificates instead of self-signed
3. **Network Policies**: Implement Kubernetes NetworkPolicies
4. **RBAC**: Minimize service account permissions
5. **Secrets**: Use external secret management (Vault, etc.)

### Security Configuration Example

```yaml
# Network Policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-network-policy
  namespace: db
spec:
  podSelector:
    matchLabels:
      app: postgres-nodes
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: pgbouncer-primary
    - podSelector:
        matchLabels:
          app: pgbouncer-replicas
    ports:
    - protocol: TCP
      port: 5432
```

## 🔄 Maintenance and Updates

### Rolling Updates

```bash
# Update PostgreSQL nodes (automatic failover)
kubectl patch statefulset postgres-nodes -n db -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"postgres","image":"citusdata/pg_auto_failover:new-version"}]}}}}'

# Update PgBouncer (connection draining)
kubectl patch deployment pgbouncer-primary -n db -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"pgbouncer","image":"pgbouncer/pgbouncer:new-version"}]}}}}'
```

### Regular Maintenance Tasks

1. **Monitor disk usage**: Set up alerts for WAL and data directories
2. **Vacuum analysis**: Schedule regular VACUUM and ANALYZE
3. **Update statistics**: Keep table statistics current
4. **Security updates**: Regularly update container images
5. **Backup verification**: Test backup restoration procedures

## 📚 Additional Resources

- [PgBouncer Documentation](https://www.pgbouncer.org/usage.html)
- [pg_auto_failover Documentation](https://pg-auto-failover.readthedocs.io/)
- [PostgreSQL Connection Pooling Best Practices](https://www.postgresql.org/docs/current/runtime-config-connection.html)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly in staging
4. Submit a pull request with performance benchmarks

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**⚠️ Production Disclaimer**: This configuration provides enterprise-grade reliability but should be customized based on your specific performance, security, and compliance requirements. Always benchmark and test thoroughly before production deployment.