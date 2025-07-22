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
- **🎯 Intelligent Connection Pooling**: PgBouncer with failover-aware routing
- **📊 Multi-tier Replication**: Synchronous + Asynchronous replicas
- **⚖️ Load Balancing**: Smart read/write traffic distribution
- **🛡️ Zero Data Loss**: Synchronous replication ensures consistency
- **⚡ Performance Optimized**: Connection pooling + tuned PostgreSQL
- **🔍 Comprehensive Monitoring**: Health checks and graceful shutdowns
- **🔐 Security First**: SSL encryption and proper authentication

## 🏗️ Architecture

### Cluster Topology with PgBouncer

<img src="./static/PostgresNetwork.png" alt="PostgresNetwork"/>

### Enhanced Failover Flow with PgBouncer

```mermaid
sequenceDiagram
    participant App as Application
    participant PgB as PgBouncer
    participant M as Monitor
    participant P as Primary
    participant S as Sync Replica
    participant A as Async Replica

    Note over App,A: Normal Operation
    App->>PgB: Connection Request
    PgB->>P: Pooled Connection (Write)
    PgB->>S: Pooled Connection (Read)
    P->>S: Sync Replication
    P->>A: Async Replication
    M->>P: Health Check ✅

    Note over App,A: Primary Failure Detected
    M->>P: Health Check ❌
    M->>S: Promote to Primary
    PgB->>PgB: Detect Connection Loss
    PgB->>S: Reconnect to New Primary
    S->>A: Async Replication (New Primary)

    Note over App,A: Seamless Service Continuation
    App->>PgB: New Connection Request
    PgB->>S: Pooled Connection (New Primary)
    Note over PgB: Connection pool maintains<br/>application transparency
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
git clone <repository-url>
cd postgres-ha-cluster
```

### 2. Deploy Prerequisites

```bash
# Create namespace
kubectl create namespace db

# Create service account and RBAC
kubectl apply -f rbac.yaml

# Create secrets for PostgreSQL
kubectl create secret generic postgres-creds \
  --from-literal=postgres-password=your-secure-password \
  --namespace=db

# Create secrets for PgBouncer
kubectl create secret generic pgbouncer-creds \
  --from-literal=admin-password=bouncer-admin-password \
  --from-literal=stats-password=bouncer-stats-password \
  --namespace=db
```

### 3. Deploy Monitor Node

```bash
# Deploy the monitor first
kubectl apply -f postgres-monitor.yaml
```

### 4. Deploy PostgreSQL Configuration

```bash
# Apply the PostgreSQL ConfigMap
kubectl apply -f postgres-configmap.yaml
```

### 5. Deploy PostgreSQL Cluster

```bash
# Deploy the PostgreSQL StatefulSet
kubectl apply -f postgres-statefulset.yaml
```

### 6. Deploy PgBouncer Configuration

```bash
# Apply PgBouncer ConfigMap
kubectl apply -f pgbouncer-configmap.yaml
```

### 7. Deploy PgBouncer Layer

```bash
# Deploy PgBouncer StatefulSet and Service
kubectl apply -f pgbouncer-statefulset.yaml
kubectl apply -f pgbouncer-service.yaml
```

### 8. Verify Deployment

```bash
# Check PostgreSQL pods
kubectl get pods -n db -l app=postgres-nodes

# Check PgBouncer pods
kubectl get pods -n db -l app=pgbouncer

# Check cluster status
kubectl exec -it postgres-nodes-0 -n db -- \
  pg_autoctl show state --pgdata /var/lib/postgresql/pgdata/master

# Check PgBouncer status
kubectl exec -it pgbouncer-0 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW POOLS;"
```

## ⚙️ Configuration Details

### PostgreSQL Node Roles

| Node | Role | Replication | Priority | PgBouncer Connection |
|------|------|-------------|----------|---------------------|
| `postgres-nodes-0` | PRIMARY | Source | 50 | Write pool target |
| `postgres-nodes-1` | SYNC REPLICA | Synchronous | 50 | Read pool + failover target |
| `postgres-nodes-2` | ASYNC REPLICA | Asynchronous | Default | Read pool |
| `postgres-nodes-3` | ASYNC REPLICA | Asynchronous | Default | Read pool |

### PgBouncer Configuration

| PgBouncer Instance | Purpose | Pool Mode | Target Nodes | Max Connections |
|-------------------|---------|-----------|--------------|-----------------|
| `pgbouncer-0` | Write Pool | Transaction | Primary only | 100 |
| `pgbouncer-1` | Read Pool | Transaction | All replicas | 200 |

### Enhanced Resource Allocation

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
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

## 🎯 PgBouncer Integration

### Connection Pool Configuration

```ini
# Write Pool (pgbouncer-0)
[databases]
writedb = host=postgres-nodes-0.postgres-nodes.db.svc.cluster.local port=5432 dbname=postgres

[pgbouncer]
pool_mode = transaction
max_client_conn = 100
default_pool_size = 20
reserve_pool_size = 5
auth_type = trust
```

```ini
# Read Pool (pgbouncer-1)
[databases]
readdb_replica1 = host=postgres-nodes-1.postgres-nodes.db.svc.cluster.local port=5432 dbname=postgres
readdb_replica2 = host=postgres-nodes-2.postgres-nodes.db.svc.cluster.local port=5432 dbname=postgres
readdb_replica3 = host=postgres-nodes-3.postgres-nodes.db.svc.cluster.local port=5432 dbname=postgres

[pgbouncer]
pool_mode = transaction
max_client_conn = 200
default_pool_size = 15
auth_type = trust
```

### Service Discovery and Load Balancing

```yaml
# PgBouncer Service Configuration
apiVersion: v1
kind: Service
metadata:
  name: pgbouncer-service
spec:
  selector:
    app: pgbouncer
  ports:
  - name: write-pool
    port: 6432
    targetPort: 6432
    protocol: TCP
  - name: read-pool
    port: 6433
    targetPort: 6432
    protocol: TCP
  type: LoadBalancer
```

## 🔍 Monitoring and Health Checks

### PostgreSQL Health Checks
- **Readiness**: `pg_isready` validation
- **Liveness**: `pg_autoctl` process + connectivity checks
- **Enhanced timing**: Failover-aware probe intervals

### PgBouncer Health Checks

```yaml
readinessProbe:
  tcpSocket:
    port: 6432
  initialDelaySeconds: 10
  periodSeconds: 15

livenessProbe:
  exec:
    command:
    - /bin/sh
    - -c
    - "echo 'SHOW STATS;' | psql -h localhost -p 6432 -U pgbouncer pgbouncer"
  initialDelaySeconds: 30
  periodSeconds: 30
```

## 🛠️ Operations Guide

### Application Connection Patterns

#### Write Operations
```python
# Python example - Write connections
import psycopg2

# Connect to write pool
write_conn = psycopg2.connect(
    host="pgbouncer-service.db.svc.cluster.local",
    port=6432,
    database="writedb",
    user="your_app_user"
)

# Perform writes
with write_conn.cursor() as cur:
    cur.execute("INSERT INTO table VALUES (%s, %s)", (value1, value2))
    write_conn.commit()
```

#### Read Operations
```python
# Read connections with load balancing
read_conn = psycopg2.connect(
    host="pgbouncer-service.db.svc.cluster.local",
    port=6433,
    database="readdb_replica1",  # or readdb_replica2, readdb_replica3
    user="your_app_user"
)

# Perform reads
with read_conn.cursor() as cur:
    cur.execute("SELECT * FROM table WHERE condition = %s", (filter_val,))
    results = cur.fetchall()
```

### Viewing Cluster Status

```bash
# PostgreSQL cluster state
kubectl exec -it postgres-nodes-0 -n db -- \
  pg_autoctl show state

# PgBouncer connection pools
kubectl exec -it pgbouncer-0 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW POOLS;"

# PgBouncer statistics
kubectl exec -it pgbouncer-1 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW STATS;"
```

### Connection Pool Management

```bash
# Reload PgBouncer configuration
kubectl exec -it pgbouncer-0 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "RELOAD;"

# Pause all connections
kubectl exec -it pgbouncer-0 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "PAUSE;"

# Resume all connections
kubectl exec -it pgbouncer-0 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "RESUME;"
```

### Manual Failover with PgBouncer

```bash
# 1. Initiate PostgreSQL failover
kubectl exec -it postgres-nodes-0 -n db -- \
  pg_autoctl perform failover

# 2. Update PgBouncer write pool target (if needed)
kubectl exec -it pgbouncer-0 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "RELOAD;"

# 3. Verify new primary connection
kubectl exec -it pgbouncer-0 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW DATABASES;"
```

## 🔐 Enhanced Security Features

### PgBouncer Security
- **Connection encryption**: SSL between applications and PgBouncer
- **Backend encryption**: SSL between PgBouncer and PostgreSQL
- **Authentication**: Separate auth for pool management
- **Network isolation**: Service-based access control

### Recommended Production Security

```yaml
# PgBouncer SSL configuration
ssl_mode = require
ssl_ca_file = /etc/ssl/certs/ca.crt
ssl_cert_file = /etc/ssl/certs/server.crt
ssl_key_file = /etc/ssl/private/server.key

# PostgreSQL SSL enforcement
ssl = on
ssl_cert_file = '/var/lib/postgresql/server.crt'
ssl_key_file = '/var/lib/postgresql/server.key'
ssl_ca_file = '/var/lib/postgresql/ca.crt'
```

## 📊 Performance Benefits with PgBouncer

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
# Reduced max_connections (pooling handles multiplexing)
max_connections = 100

# Optimized for fewer, longer-lived connections
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 8MB
```

#### PgBouncer (Transaction pooling)
```ini
# Optimal for OLTP workloads
pool_mode = transaction
default_pool_size = 20
reserve_pool_size = 5
server_round_robin = 1
```

## 🚨 Troubleshooting

### PgBouncer Issues

#### Connection Pool Exhaustion
```bash
# Check pool status
kubectl exec -it pgbouncer-0 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW POOLS;"

# Check waiting clients
kubectl exec -it pgbouncer-0 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW CLIENTS;"
```

#### Backend Connection Issues
```bash
# Check server connections
kubectl exec -it pgbouncer-0 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "SHOW SERVERS;"

# Kill problematic connections
kubectl exec -it pgbouncer-0 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "KILL <pid>;"
```

### Split-brain Prevention
- Monitor node coordinates all decisions
- PgBouncer respects PostgreSQL cluster state
- Automatic reconnection to new primary

## 🔄 Maintenance and Updates

### Rolling Updates with Zero Downtime

```bash
# Update PostgreSQL nodes (automatic failover)
kubectl patch statefulset postgres-nodes -n db -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"postgres","image":"citusdata/pg_auto_failover:new-version"}]}}}}'

# Update PgBouncer (connection draining)
kubectl patch statefulset pgbouncer -n db -p \
  '{"spec":{"template":{"spec":{"containers":[{"name":"pgbouncer","image":"pgbouncer/pgbouncer:new-version"}]}}}}'
```

### Configuration Management

```bash
# Update PgBouncer configuration
kubectl apply -f pgbouncer-configmap.yaml

# Reload without restart (preserves connections)
kubectl exec -it pgbouncer-0 -n db -- \
  psql -h localhost -p 6432 -U pgbouncer -d pgbouncer -c "RELOAD;"
```

## 📈 Scaling Strategies

### Horizontal Scaling
- **PostgreSQL replicas**: Add more async replicas for read scaling
- **PgBouncer instances**: Add dedicated pools for different workload types
- **Geographic distribution**: Deploy PgBouncer closer to applications

### Advanced Pool Configurations

```ini
# Workload-specific pools
[databases]
analytics = host=postgres-nodes-2 port=5432 dbname=postgres pool_size=10
reporting = host=postgres-nodes-3 port=5432 dbname=postgres pool_size=15
oltp = host=postgres-nodes-0 port=5432 dbname=postgres pool_size=25
```

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