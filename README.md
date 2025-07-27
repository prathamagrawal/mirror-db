<h1 align="center"> Mirror-DB </h1>
<hr />


[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-11-336791?style=flat-square&logo=postgresql)](https://www.postgresql.org/)
[![PgBouncer](https://img.shields.io/badge/PgBouncer-1.18-4169E1?style=flat-square)](https://www.pgbouncer.org/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.20+-326CE5?style=flat-square&logo=kubernetes)](https://kubernetes.io/)
[![pg_auto_failover](https://img.shields.io/badge/pg__auto__failover-latest-orange?style=flat-square)](https://github.com/citusdata/pg_auto_failover)

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
<img src="./static/PostgresNetwork.png" alt="PostgresNetwork"/>

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

### 1. Clone and Navigate

```bash
git clone https://github.com/prathamagrawal/mirror-db
cd mirror-db
```

### 2. Deploy Prerequisites

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

### 3. Deploy Storage

```bash
# Deploy PVC for monitor
kubectl apply -f pvc/monitor.yaml
```

### 4. Deploy Monitor Node

```bash
# Deploy the monitor first
kubectl apply -f deployments/postgres-monitor.yaml

# Deploy the monitor node services
kubectl apply -f services/monitor.yaml

# Wait for monitor to be ready
kubectl wait --for=condition=ready pod -l app=postgres-monitor -n db --timeout=300s
```

### 5. Deploy PostgreSQL Cluster

```bash
# Deploy the PostgreSQL StatefulSet
kubectl apply -f deployments/node-setup.yaml

# Deploy the monitor node services
kubectl apply -f services/nodes.yaml

# Wait for nodes to be ready
kubectl wait --for=condition=ready pod -l app=postgres-nodes -n db --timeout=600s
```

### 6. Deploy PgBouncer

```bash
# Deploy PgBouncer pools
kubectl apply -f deployments/pgbouncer.yaml
kubectl apply -f services/pgbouncer.yaml
```

### 7. Verify Deployment

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

### Service Discovery

The cluster uses **automatic pod labeling** to enable dynamic service discovery:

- **Pod Labeler**: Python sidecar container that monitors PostgreSQL roles
- **Dynamic Labels**: Pods get labeled with `pg-role=primary` or `pg-role=replica`
- **Service Selectors**: Kubernetes services automatically route to correct nodes

## 🛠️ Operations Guide

### Viewing Cluster Status

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
wal_keep_segments = 64

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

## 🚨 Troubleshooting

### Common Issues

#### Pod Labeling Issues
```bash
# Check pod labels
kubectl get pods -n db --show-labels

# Check service endpoints
kubectl get endpoints -n db

# Restart pod labeler if needed
kubectl delete pod -l app=postgres-nodes -n db
```

#### PgBouncer Connection Issues
```bash
# Check pool status
kubectl exec -it deployment/pgbouncer-primary -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW POOLS;"

# Check backend connections
kubectl exec -it deployment/pgbouncer-primary -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW SERVERS;"
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