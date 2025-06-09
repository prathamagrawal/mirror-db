#!/bin/bash
set -e

echo "Setting up PostgreSQL replica..."
echo "Replica type: ${REPLICA_TYPE:-async}"

# Wait for master
until pg_isready -h postgres-master -p 5432; do
  echo "Waiting for master..."
  sleep 2
done

# Check if already initialized
if [ -s "/var/lib/postgresql/data/PG_VERSION" ]; then
  echo "Data directory already initialized, starting as replica..."
  exec gosu postgres postgres -c config_file=/etc/postgresql/postgresql.conf
fi

echo "Initializing replica from master..."

# Ensure we're running as postgres user for file operations
if [ "$(id -u)" = "0" ]; then
  # If running as root, switch to postgres user for data operations
  echo "Switching to postgres user for data operations..."

  # Create a temporary script to run as postgres user
  cat > /tmp/setup_replica_as_postgres.sh << 'SCRIPT_EOF'
#!/bin/bash
set -e

# Clear data directory completely and aggressively
echo "Clearing data directory..."
if [ -d "/var/lib/postgresql/data" ]; then
  # Stop any processes that might be using the directory
  fuser -k /var/lib/postgresql/data 2>/dev/null || true
  sleep 1

  # Remove everything with extreme prejudice
  rm -rf /var/lib/postgresql/data/* 2>/dev/null || true
  rm -rf /var/lib/postgresql/data/.* 2>/dev/null || true

  # Create fresh directory
  mkdir -p /var/lib/postgresql/data
  chmod 700 /var/lib/postgresql/data
fi

# Create base backup with unique slot name based on hostname and type
REPLICA_SLOT_NAME="replica_slot_$(hostname | tr '-' '_')"
echo "Using replication slot: $REPLICA_SLOT_NAME"

# Use a temporary directory for basebackup then move
TEMP_DATA_DIR="/tmp/pg_backup_$(date +%s)"
mkdir -p "$TEMP_DATA_DIR"

echo "Creating base backup in temporary directory..."
PGPASSWORD=replicauser123 pg_basebackup \
  -h postgres-master \
  -p 5432 \
  -U replicauser \
  -D "$TEMP_DATA_DIR" \
  -P -W -R -X stream \
  --slot="$REPLICA_SLOT_NAME" \
  --create-slot

echo "Moving backup to final location..."
# Ensure target is clean
rm -rf /var/lib/postgresql/data/*
rm -rf /var/lib/postgresql/data/.*

# Move data from temp location
mv "$TEMP_DATA_DIR"/* /var/lib/postgresql/data/
mv "$TEMP_DATA_DIR"/.[!.]* /var/lib/postgresql/data/ 2>/dev/null || true
rmdir "$TEMP_DATA_DIR"

# Set proper permissions
chmod 700 /var/lib/postgresql/data

# Determine application name based on replica type
if [ "${REPLICA_TYPE}" = "sync" ]; then
  APP_NAME="postgres_sync_replica"
else
  APP_NAME="postgres_async_replica"
fi

# Update recovery settings with unique slot name and application name
cat >> /var/lib/postgresql/data/postgresql.auto.conf <<EOF
primary_conninfo = 'host=postgres-master port=5432 user=replicauser password=replicauser123 application_name=$APP_NAME'
primary_slot_name = '$REPLICA_SLOT_NAME'
hot_standby = on
EOF

echo "Replica setup completed! (Type: ${REPLICA_TYPE:-async})"
SCRIPT_EOF

  chmod +x /tmp/setup_replica_as_postgres.sh
  gosu postgres /tmp/setup_replica_as_postgres.sh
else
  # Already running as postgres user
  # Clear data directory completely and aggressively
  echo "Clearing data directory..."
  if [ -d "/var/lib/postgresql/data" ]; then
    # Stop any processes that might be using the directory
    fuser -k /var/lib/postgresql/data 2>/dev/null || true
    sleep 1

    # Remove everything with extreme prejudice
    rm -rf /var/lib/postgresql/data/* 2>/dev/null || true
    rm -rf /var/lib/postgresql/data/.* 2>/dev/null || true

    # Create fresh directory
    mkdir -p /var/lib/postgresql/data
    chmod 700 /var/lib/postgresql/data
  fi

  # Create base backup with unique slot name based on hostname and type
  REPLICA_SLOT_NAME="replica_slot_$(hostname | tr '-' '_')"
  echo "Using replication slot: $REPLICA_SLOT_NAME"

  # Use a temporary directory for basebackup then move
  TEMP_DATA_DIR="/tmp/pg_backup_$(date +%s)"
  mkdir -p "$TEMP_DATA_DIR"

  echo "Creating base backup in temporary directory..."
  PGPASSWORD=replicauser123 pg_basebackup \
    -h postgres-master \
    -p 5432 \
    -U replicauser \
    -D "$TEMP_DATA_DIR" \
    -P -W -R -X stream \
    --slot="$REPLICA_SLOT_NAME" \
    --create-slot

  echo "Moving backup to final location..."
  # Ensure target is clean
  rm -rf /var/lib/postgresql/data/*
  rm -rf /var/lib/postgresql/data/.*

  # Move data from temp location
  mv "$TEMP_DATA_DIR"/* /var/lib/postgresql/data/
  mv "$TEMP_DATA_DIR"/.[!.]* /var/lib/postgresql/data/ 2>/dev/null || true
  rmdir "$TEMP_DATA_DIR"

  # Set proper permissions
  chmod 700 /var/lib/postgresql/data

  # Determine application name based on replica type
  if [ "${REPLICA_TYPE}" = "sync" ]; then
    APP_NAME="postgres_sync_replica"
  else
    APP_NAME="postgres_async_replica"
  fi

  # Update recovery settings with unique slot name and application name
  cat >> /var/lib/postgresql/data/postgresql.auto.conf <<EOF
primary_conninfo = 'host=postgres-master port=5432 user=replicauser password=replicauser123 application_name=$APP_NAME'
primary_slot_name = '$REPLICA_SLOT_NAME'
hot_standby = on
EOF

  echo "Replica setup completed! (Type: ${REPLICA_TYPE:-async})"
fi

echo "Starting PostgreSQL..."
# Start PostgreSQL as postgres user
exec gosu postgres postgres -c config_file=/etc/postgresql/postgresql.conf