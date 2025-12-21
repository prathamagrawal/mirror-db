# Release Notes

## v1.1.0 - Helm Chart & Improvements

**Release Date:** December 17, 2025

This release introduces a complete Helm chart for simplified deployment and includes several improvements to the PostgreSQL HA cluster setup.

---

### 🚀 New Features

#### Helm Chart Support
- **Full Helm chart** for deploying the PostgreSQL HA cluster with a single command
- **Configurable values** for all components (PostgreSQL, PgBouncer, Monitor)
- **Example value files** for different environments:
  - `values-development.yaml` - Minimal resources for local development
  - `values-production.yaml` - Production-ready configuration with HA
  - `values-minimal.yaml` - CI/CD and quick testing
- **Helm tests** for validating deployments

#### Deployment Options
```bash
# Quick install with Helm
helm install mirror-db ./helm/mirror-db -n db --create-namespace

# Or use Kustomize
kubectl apply -k .
```

---

### 🔧 Improvements

- **Monitor node setup** - Fixed initialization and configuration issues
- **Node setup fixes** - Improved reliability of PostgreSQL node bootstrapping
- **Documentation** - Comprehensive README with architecture diagrams, troubleshooting guides, and operational procedures
- **Test cases** - Added testing resources for validation

---

### 📦 What's Included

| Component | Version | Description |
|-----------|---------|-------------|
| PostgreSQL | 15 | Primary database with pg_auto_failover |
| pg_auto_failover | 2.0 | Automatic failover management |
| PgBouncer | 1.22 | Connection pooling |
| Helm Chart | 0.1.0 | Kubernetes deployment |

---

### 🏗️ Architecture Highlights

- **Automatic Failover** - Sub-minute failover with health monitoring
- **Connection Pooling** - Separate pools for primary (writes) and replicas (reads)
- **Dynamic Service Discovery** - Automatic pod labeling for service routing
- **Multi-tier Replication** - Synchronous + Asynchronous replicas
- **Zero Data Loss** - Synchronous replication ensures consistency

---

### 📋 Installation

#### Prerequisites
- Kubernetes cluster v1.20+
- Helm v3.0+ (for Helm installation)
- kubectl configured
- Storage class available

#### Quick Start

**Option 1: Helm (Recommended)**
```bash
git clone https://github.com/prathamagrawal/mirror-db
cd mirror-db
helm install mirror-db ./helm/mirror-db -n db --create-namespace
```

**Option 2: Kustomize**
```bash
git clone https://github.com/prathamagrawal/mirror-db
cd mirror-db
kubectl apply -k .
```

---

### ⚙️ Configuration

Key Helm values:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `postgresql.cluster.replicaCount` | 4 | Number of PostgreSQL nodes |
| `postgresql.storage.size` | 50Gi | Storage per node |
| `pgbouncer.enabled` | true | Enable connection pooling |
| `pgbouncer.pooling.mode` | transaction | Pool mode |
| `ha.podDisruptionBudget.enabled` | true | Enable PDBs |

See `helm/mirror-db/values.yaml` for full configuration options.

---

### 🔄 Upgrading from v1.0.0

If upgrading from v1.0.0 (Kustomize-only):

```bash
# Option 1: Switch to Helm
kubectl delete -k .
helm install mirror-db ./helm/mirror-db -n db --create-namespace

# Option 2: Continue with Kustomize
kubectl apply -k .
```

> ⚠️ **Note:** Switching deployment methods requires careful data migration. Back up your data before upgrading.

---

### 📝 Full Changelog

- `ef2ec69` - feat: Add Helm chart for simplified deployment
- `7e3ac17` - chore: Add test cases for validation
- `0128c85` - fix: Monitor and node setup fixes
- `870efc3` - docs: Update README with comprehensive documentation
- `755d016` - docs: Updated README structure

---

### 🙏 Contributors

- Pratham Agrawal ([@prathamagrawal](https://github.com/prathamagrawal))

---

### 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

**Full Changelog:** [v1.0.0...v1.1.0](https://github.com/prathamagrawal/mirror-db/compare/v1.0.0...v1.1.0)

