#!/bin/bash
set -e

echo "Setting up PostgreSQL replica..."

# Wait for master
until pg_isready -h postgres-master -p 5433; do
  echo "Waiting for master..."
  sleep 2
done

# Check if already initialized
if [ -s "/var/lib/postgresql/data/PG_VERSION" ]; then
  echo "Data directory already initialized, starting as replica..."
  exec gosu postgres postgres
fi

echo "Initializing replica from master..."

# Clear data directory
rm -rf /var/lib/postgresql/data/*

# Create base backup
PGPASSWORD=replicauser123 pg_basebackup \
  -h postgres-master \
  -p 5433 \
  -U replicauser \
  -D /var/lib/postgresql/data \
  -P -W -R -X stream

# Set permissions
chown -R postgres:postgres /var/lib/postgresql/data
chmod 700 /var/lib/postgresql/data

# Update recovery settings
cat >> /var/lib/postgresql/data/postgresql.auto.conf <<EOF
primary_conninfo = 'host=postgres-master port=5433 user=replicauser password=replicauser123'
primary_slot_name = 'replica_slot'
hot_standby = on
EOF

echo "Replica setup completed! Starting PostgreSQL..."

# Start PostgreSQL as postgres user
exec gosu postgres postgres