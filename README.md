<h1 align="center">Mirror-DB</h1>

<p align="center">
  <strong>Enterprise-grade PostgreSQL High Availability Cluster for Kubernetes</strong>
</p>

<p align="center">
  <a href="https://www.postgresql.org/"><img src="https://img.shields.io/badge/PostgreSQL-15-336791?style=flat-square&logo=postgresql" alt="PostgreSQL"></a>
  <a href="https://www.pgbouncer.org/"><img src="https://img.shields.io/badge/PgBouncer-1.22-4169E1?style=flat-square" alt="PgBouncer"></a>
  <a href="https://kubernetes.io/"><img src="https://img.shields.io/badge/Kubernetes-1.20+-326CE5?style=flat-square&logo=kubernetes" alt="Kubernetes"></a>
  <a href="https://github.com/citusdata/pg_auto_failover"><img src="https://img.shields.io/badge/pg__auto__failover-2.0-orange?style=flat-square" alt="pg_auto_failover"></a>
  <a href="https://helm.sh/"><img src="https://img.shields.io/badge/Helm-3.0+-0F1689?style=flat-square&logo=helm" alt="Helm"></a>
  <a href="https://kustomize.io/"><img src="https://img.shields.io/badge/Kustomize-ready-green?style=flat-square" alt="Kustomize"></a>
</p>

---

## Overview

Mirror-DB provides a production-ready PostgreSQL High Availability setup using **pg_auto_failover** with **PgBouncer** connection pooling on Kubernetes. Features include automatic failover, read/write splitting, connection pooling, and dynamic service discovery.

### Key Features

| Feature | Description |
|---------|-------------|
| 🔄 **Automatic Failover** | Sub-minute failover with health monitoring |
| 🎯 **Connection Pooling** | PgBouncer with separate primary/replica pools |
| 📊 **Multi-tier Replication** | Synchronous + Asynchronous replicas |
| ⚖️ **Load Balancing** | Smart read/write traffic distribution |
| 🛡️ **Zero Data Loss** | Synchronous replication ensures consistency |
| 🏷️ **Dynamic Discovery** | Automatic pod labeling for service routing |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Applications                                 │
│              ┌──────────────┐        ┌──────────────┐               │
│              │  Write Apps  │        │  Read Apps   │               │
│              └──────┬───────┘        └──────┬───────┘               │
└─────────────────────┼───────────────────────┼───────────────────────┘
                      │                       │
                      ▼                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    PgBouncer Connection Pools                        │
│     ┌─────────────────────┐        ┌─────────────────────┐          │
│     │  pgbouncer-primary  │        │  pgbouncer-replicas │          │
│     │     Port: 6432      │        │     Port: 6432      │          │
│     └──────────┬──────────┘        └──────────┬──────────┘          │
└────────────────┼──────────────────────────────┼─────────────────────┘
                 │                              │
                 ▼                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Kubernetes Services                             │
│     ┌─────────────────────┐        ┌─────────────────────┐          │
│     │   postgres-primary  │        │  postgres-replicas  │          │
│     │  (pg-role: primary) │        │  (pg-role: replica) │          │
│     └──────────┬──────────┘        └──────────┬──────────┘          │
└────────────────┼──────────────────────────────┼─────────────────────┘
                 │                              │
                 ▼                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 PostgreSQL Cluster (StatefulSet)                     │
│                                                                      │
│  ┌──────────┐   ┌──────────────────────────────────────────────┐    │
│  │ Monitor  │   │              Data Nodes                       │    │
│  │ Port:6001│   │  ┌─────────┐ ┌─────────┐ ┌─────────┐         │    │
│  │          │   │  │Primary  │ │  Sync   │ │  Async  │ ...     │    │
│  │Coordinates│   │  │(node-0) │ │(node-1) │ │(node-2) │         │    │
│  │ Failover │   │  └────┬────┘ └────┬────┘ └────┬────┘         │    │
│  └──────────┘   │       └───────────┴───────────┘               │    │
│                 │            Streaming Replication              │    │
│                 └──────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.20+)
- `kubectl` configured
- `helm` v3.0+ (for Helm installation)
- Storage class available (default or custom)

### Option 1: Helm (Recommended)

```bash
# Clone repository
git clone https://github.com/prathamagrawal/mirror-db
cd mirror-db

# Install with defaults
helm install mirror-db ./helm/mirror-db -n db --create-namespace

# Watch pods come up
kubectl get pods -n db -w
```

### Option 2: Kustomize

```bash
# Clone repository
git clone https://github.com/prathamagrawal/mirror-db
cd mirror-db

# Deploy base configuration
kubectl apply -k .

# Watch pods come up
kubectl get pods -n db -w
```

---

## Helm Chart

### Installation

```bash
# Default installation
helm install mirror-db ./helm/mirror-db -n db --create-namespace

# Development (minimal resources)
helm install mirror-db ./helm/mirror-db -n db-dev --create-namespace \
  -f ./helm/mirror-db/examples/values-development.yaml

# Production
helm install mirror-db ./helm/mirror-db -n db-prod --create-namespace \
  -f ./helm/mirror-db/examples/values-production.yaml

# Custom values
helm install mirror-db ./helm/mirror-db -n db --create-namespace \
  --set postgresql.cluster.replicaCount=6 \
  --set postgresql.storage.size=100Gi
```

### Management Commands

```bash
# Upgrade
helm upgrade mirror-db ./helm/mirror-db -n db

# Rollback
helm rollback mirror-db 1 -n db

# Uninstall
helm uninstall mirror-db -n db

# Test
helm test mirror-db -n db

# Dry-run
helm install mirror-db ./helm/mirror-db -n db --dry-run
```

### Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.cluster.replicaCount` | Number of PostgreSQL nodes | `4` |
| `postgresql.storage.size` | Storage per node | `50Gi` |
| `postgresql.resources.requests.memory` | Memory request | `512Mi` |
| `postgresql.resources.limits.memory` | Memory limit | `1Gi` |
| `postgresql.tuning.maxConnections` | Max DB connections | `250` |
| `monitor.storage.size` | Monitor storage | `10Gi` |
| `pgbouncer.enabled` | Enable PgBouncer | `true` |
| `pgbouncer.replicas` | PgBouncer instances | `1` |
| `pgbouncer.pooling.mode` | Pool mode | `transaction` |
| `pgbouncer.pooling.maxClientConn` | Max client connections | `100` |
| `credentials.postgres.password` | Postgres password | `postgres123` |
| `ha.podDisruptionBudget.enabled` | Enable PDBs | `true` |
| `networkPolicy.enabled` | Enable network policies | `false` |

### Example Values Files

| File | Use Case |
|------|----------|
| `examples/values-development.yaml` | Local dev, minikube, kind |
| `examples/values-production.yaml` | Production with HA |
| `examples/values-minimal.yaml` | CI/CD, quick testing |

---

## Kustomize

### Deployment

```bash
# Base configuration
kubectl apply -k .

# Development overlay
kubectl apply -k overlays/development/

# Production overlay
kubectl apply -k overlays/production/

# Preview changes
kubectl kustomize overlays/production/
```

### Environment Comparison

| Setting | Base | Development | Production |
|---------|------|-------------|------------|
| Namespace | `db` | `db-dev` | `db-production` |
| Replicas | 4 | 2 | 4 |
| Memory | 512Mi-1Gi | 256Mi-512Mi | 2Gi-4Gi |
| Storage | 50Gi | 10Gi | 200Gi |

---

## Connection Endpoints

### Service Endpoints

| Service | Purpose | Port | DNS |
|---------|---------|------|-----|
| `pgbouncer-primary-service` | Writes (pooled) | 6432 | `pgbouncer-primary-service.<namespace>.svc.cluster.local` |
| `pgbouncer-replicas-service` | Reads (pooled) | 6432 | `pgbouncer-replicas-service.<namespace>.svc.cluster.local` |
| `postgres-primary` | Direct primary | 5432 | `postgres-primary.<namespace>.svc.cluster.local` |
| `postgres-replicas` | Direct replicas | 5432 | `postgres-replicas.<namespace>.svc.cluster.local` |
| `postgres-monitor` | Monitor | 6001 | `postgres-monitor.<namespace>.svc.cluster.local` |

### Connection Strings

```bash
# Via PgBouncer (recommended)
postgresql://postgres:password@pgbouncer-primary-service.db.svc.cluster.local:6432/postgres

# Direct to primary
postgresql://postgres:password@postgres-primary.db.svc.cluster.local:5432/postgres
```

---

## Operations

### Check Cluster Status

```bash
# Pod status
kubectl get pods -n db

# Cluster state
kubectl exec -n db postgres-nodes-0 -c postgres -- pg_autoctl show state

# Pod labels (primary/replica)
kubectl get pods -n db -l app=postgres-nodes --show-labels

# Service endpoints
kubectl get endpoints -n db
```

### Connect to Database

```bash
# Via kubectl exec
kubectl exec -it -n db postgres-nodes-0 -c postgres -- psql -U postgres

# Via port-forward
kubectl port-forward -n db svc/pgbouncer-primary-service 6432:6432
psql -h localhost -p 6432 -U postgres
```

### Manual Failover

```bash
# Trigger failover
kubectl exec -n db postgres-nodes-0 -c postgres -- \
  pg_autoctl perform failover

# Watch failover
watch kubectl get pods -n db -l app=postgres-nodes --show-labels
```

### View Logs

```bash
# Monitor logs
kubectl logs -n db -l app=postgres-monitor -f

# Node logs
kubectl logs -n db postgres-nodes-0 -c postgres -f

# Pod labeler logs
kubectl logs -n db postgres-nodes-0 -c pod-labeler -f

# PgBouncer logs
kubectl logs -n db -l app=pgbouncer-primary -f
```

### Scaling

```bash
# Scale PostgreSQL nodes (Helm)
helm upgrade mirror-db ./helm/mirror-db -n db \
  --set postgresql.cluster.replicaCount=6

# Scale PostgreSQL nodes (kubectl)
kubectl scale statefulset postgres-nodes -n db --replicas=6

# Scale PgBouncer
kubectl scale deployment pgbouncer-primary -n db --replicas=3
```

### Get Credentials

```bash
# Get password (Helm)
kubectl get secret -n db -l app.kubernetes.io/instance=mirror-db \
  -o jsonpath="{.items[0].data.postgres-password}" | base64 -d

# Get password (Kustomize)
kubectl get secret postgres-creds -n db \
  -o jsonpath="{.data.postgres-password}" | base64 -d
```

---

## Cleanup

```bash
# Helm
helm uninstall mirror-db -n db
kubectl delete pvc -n db --all
kubectl delete namespace db

# Kustomize
kubectl delete -k .
kubectl delete pvc -n db --all
kubectl delete namespace db
```

---

## Project Structure

```
mirror-db/
├── helm/mirror-db/              # Helm Chart
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   └── examples/
│       ├── values-development.yaml
│       ├── values-production.yaml
│       └── values-minimal.yaml
├── configuration/               # Kustomize configs
├── deployments/                 # Kustomize deployments
├── services/                    # Kustomize services
├── overlays/                    # Kustomize overlays
│   ├── development/
│   └── production/
└── kustomization.yaml
```

---

## Troubleshooting

### Pods Stuck in Pending

```bash
# Check PVC status
kubectl get pvc -n db

# Check events
kubectl describe pod <pod-name> -n db
```

**Solution**: Ensure storage class exists or remove `storageClassName` to use default.

### ImagePullBackOff

```bash
kubectl describe pod <pod-name> -n db | grep -A5 Events
```

**Solution**: Check image tags exist on Docker Hub.

### Pod Labeler Failing

```bash
kubectl logs -n db postgres-nodes-0 -c pod-labeler
```

**Solution**: Ensure RBAC is properly configured.

### PgBouncer Connection Issues

```bash
# Check config
kubectl exec -n db deployment/pgbouncer-primary -- cat /etc/pgbouncer/pgbouncer.ini

# Check pools
kubectl exec -it -n db deployment/pgbouncer-primary -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW POOLS;"
```

---

## Failover Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| Detection | 10-30s | Monitor detects failure |
| Promotion | 5-10s | Replica promoted to primary |
| Label Update | 1-5s | Pod labeler updates labels |
| Routing | 1-5s | Services route to new primary |
| **Total** | **~30-60s** | Complete failover |

---

## Security Considerations

For production deployments:

1. **Credentials**: Use external secret management (Vault, AWS Secrets Manager)
2. **Network**: Enable `networkPolicy.enabled: true`
3. **TLS**: Configure proper certificates
4. **RBAC**: Minimize service account permissions

---

## Additional Resources

- [pg_auto_failover Documentation](https://pg-auto-failover.readthedocs.io/)
- [PgBouncer Documentation](https://www.pgbouncer.org/usage.html)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

---

## License

MIT License - see [LICENSE](LICENSE) for details.
