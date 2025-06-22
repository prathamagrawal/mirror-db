<h1 align="center">Mirror-DB</h1>
<hr>

### To connect with the postgres outside the cluster

```bash
minikube service postgres-external -n db --url
```
```bash
kubectl port-forward -n db svc/postgres-external 5432:5432
```


# 2-Week Kubernetes & PostgreSQL HA Learning Plan

## Week 1: Kubernetes Fundamentals + Basic PostgreSQL Concepts

### Day 1: Kubernetes Basics
**Morning (3-4 hours)**
- Kubernetes architecture overview (control plane, nodes, pods)
- Core concepts: Pods, Services, Deployments
- Install local Kubernetes (minikube, kind, or Docker Desktop)

**Afternoon (2-3 hours)**
- Hands-on: Deploy your first pod and service
- Understanding kubectl basics
- Explore cluster with `kubectl get`, `describe`, `logs`

**Evening Study (1 hour)**
- Read Kubernetes documentation on Pods and Services
- Watch: "Kubernetes Explained in 15 Minutes" videos

### Day 2: Kubernetes Workloads & Storage
**Morning (3-4 hours)**
- Deployments vs StatefulSets (crucial for databases)
- ReplicaSets and scaling concepts
- Understand when to use each workload type

**Afternoon (2-3 hours)**
- Persistent Volumes (PV) and Persistent Volume Claims (PVC)
- Storage Classes and dynamic provisioning
- Hands-on: Create a StatefulSet with persistent storage

**Evening Study (1 hour)**
- PostgreSQL basics: installation, basic configuration
- Understanding PostgreSQL data directory structure

### Day 3: Kubernetes Configuration & Secrets
**Morning (3-4 hours)**
- ConfigMaps for application configuration
- Secrets for sensitive data (passwords, certificates)
- Environment variables and volume mounts

**Afternoon (2-3 hours)**
- Hands-on: Deploy PostgreSQL single instance on Kubernetes
- Use ConfigMaps for PostgreSQL configuration
- Use Secrets for database credentials

**Evening Study (1 hour)**
- PostgreSQL replication concepts overview
- Read about master-slave vs master-standby terminology

### Day 4: Kubernetes Networking
**Morning (3-4 hours)**
- Services: ClusterIP, NodePort, LoadBalancer
- Headless services (important for StatefulSets)
- Service discovery and DNS in Kubernetes

**Afternoon (2-3 hours)**
- Ingress controllers and ingress resources
- Network policies basics
- Hands-on: Expose your PostgreSQL with different service types

**Evening Study (1 hour)**
- PostgreSQL streaming replication fundamentals
- Understanding WAL (Write-Ahead Logging)

### Day 5: Advanced Kubernetes Concepts
**Morning (3-4 hours)**
- Init containers and sidecar patterns
- Pod lifecycle and restart policies
- Health checks: liveness, readiness, startup probes

**Afternoon (2-3 hours)**
- Jobs and CronJobs
- DaemonSets
- Hands-on: Add health checks to your PostgreSQL deployment

**Evening Study (1 hour)**
- PostgreSQL backup and recovery concepts
- Point-in-time recovery (PITR) basics

### Day 6: Kubernetes Operators & Custom Resources
**Morning (3-4 hours)**
- Understanding Operators pattern
- Custom Resource Definitions (CRDs)
- Popular database operators overview

**Afternoon (2-3 hours)**
- Explore existing PostgreSQL operators:
  - CloudNativePG
  - Crunchy PostgreSQL Operator
  - Zalando PostgreSQL Operator
- Install and test one operator

**Evening Study (1 hour)**
- Research pg_auto_failover architecture
- Compare with other HA solutions (Patroni, Stolon)

### Day 7: Weekend Project & Review
**Morning (3-4 hours)**
- Set up PostgreSQL primary-secondary replication manually
- Test failover scenarios manually
- Document your findings

**Afternoon (2-3 hours)**
- Review Week 1 concepts
- Create a simple Kubernetes cheat sheet
- Plan Week 2 focus areas

## Week 2: PostgreSQL HA Deep Dive + pg_auto_failover Implementation

### Day 8: PostgreSQL HA Architecture Deep Dive
**Morning (3-4 hours)**
- PostgreSQL replication types: streaming, logical, physical
- Synchronous vs asynchronous replication
- Understanding recovery.conf and postgresql.conf for replication

**Afternoon (2-3 hours)**
- Failover vs switchover concepts
- Split-brain scenarios and prevention
- Hands-on: Set up streaming replication outside Kubernetes

**Evening Study (1 hour)**
- Read pg_auto_failover documentation
- Understand monitor node concept

### Day 9: pg_auto_failover Fundamentals
**Morning (3-4 hours)**
- pg_auto_failover architecture and components
- Monitor node setup and configuration
- State machine and health checks

**Afternoon (2-3 hours)**
- Install pg_auto_failover locally
- Set up monitor node
- Add primary and secondary nodes

**Evening Study (1 hour)**
- Study pg_auto_failover Kubernetes examples
- Review container images available

### Day 10: Kubernetes Monitoring & Observability
**Morning (3-4 hours)**
- Prometheus and Grafana basics
- PostgreSQL metrics and exporters
- ServiceMonitor and PodMonitor concepts

**Afternoon (2-3 hours)**
- Set up monitoring stack in Kubernetes
- Deploy PostgreSQL exporter
- Create basic dashboards

**Evening Study (1 hour)**
- Research backup strategies for Kubernetes PostgreSQL
- Study persistent volume backup solutions

### Day 11: pg_auto_failover on Kubernetes - Planning
**Morning (3-4 hours)**
- Design Kubernetes manifests for pg_auto_failover
- Plan StatefulSet configurations
- Design service discovery strategy

**Afternoon (2-3 hours)**
- Create ConfigMaps for pg_auto_failover configuration
- Design secrets management
- Plan persistent volume strategy

**Evening Study (1 hour)**
- Review security best practices
- Study RBAC requirements

### Day 12: Implementation Day 1
**Morning (3-4 hours)**
- Implement monitor node StatefulSet
- Create necessary services and ConfigMaps
- Test monitor node deployment

**Afternoon (2-3 hours)**
- Implement primary PostgreSQL node
- Configure replication settings
- Test primary node connectivity to monitor

**Evening Study (1 hour)**
- Debug any issues encountered
- Research troubleshooting techniques

### Day 13: Implementation Day 2
**Morning (3-4 hours)**
- Implement secondary PostgreSQL node(s)
- Configure automatic failover settings
- Test replication setup

**Afternoon (2-3 hours)**
- Implement monitoring and alerting
- Add health checks and probes
- Test cluster operations

**Evening Study (1 hour)**
- Document your implementation
- Create troubleshooting guide

### Day 14: Testing & Optimization
**Morning (3-4 hours)**
- Comprehensive testing:
  - Planned failover scenarios
  - Unplanned failure simulations
  - Network partition testing
  - Pod restart scenarios

**Afternoon (2-3 hours)**
- Performance tuning and optimization
- Security hardening
- Backup and restore testing

**Evening Study (1 hour)**
- Final documentation
- Plan for production considerations
- Identify areas for further learning

## Daily Structure Recommendations

### Time Allocation
- **Morning Session**: 3-4 hours of focused learning/implementation
- **Afternoon Session**: 2-3 hours of hands-on practice
- **Evening Study**: 1 hour of reading/research

### Learning Resources

**Kubernetes**
- Official Kubernetes documentation
- "Kubernetes Up & Running" book
- Kubernetes Academy courses
- YouTube: TechWorld with Nana

**PostgreSQL HA**
- Official PostgreSQL documentation
- "PostgreSQL High Availability Cookbook"
- pg_auto_failover official docs
- Citusdata blog posts

**Tools to Install**
- Docker Desktop or similar
- kubectl
- minikube or kind
- PostgreSQL client tools
- Helm (for Week 2)

### Hands-on Labs Environment
- Start with local Kubernetes (minikube/kind)
- Use cloud provider free tier if needed (GKE, EKS, AKS)
- Document all commands and configurations

### Success Metrics

**End of Week 1**
- Can deploy and manage basic Kubernetes workloads
- Understand StatefulSets and persistent storage
- Have working single PostgreSQL instance on Kubernetes

**End of Week 2**
- Have functioning pg_auto_failover cluster on Kubernetes
- Can demonstrate failover scenarios
- Understand monitoring and troubleshooting
- Have documented architecture and procedures

### Additional Tips
- Join Kubernetes and PostgreSQL community forums
- Practice kubectl commands daily
- Keep a learning journal with commands and concepts
- Don't rush - understanding is more important than speed
- Ask questions in relevant Slack/Discord communities

### Backup Plans
- If pg_auto_failover proves too complex, pivot to simpler HA solutions
- If Kubernetes learning is slower, extend timeline
- Focus on understanding over completion