#!/bin/bash
set -e

# Create replication user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER $POSTGRES_REPLICATION_USER REPLICATION LOGIN CONNECTION LIMIT 5 ENCRYPTED PASSWORD '$POSTGRES_REPLICATION_PASSWORD';
EOSQL

echo "synchronous_standby_names = '1 (postgres_sync_replica)'" >> /var/lib/postgresql/data/postgresql.auto.conf
#echo "synchronous_commit = on" >> /var/lib/postgresql/data/postgresql.auto.conf
echo "Master database initialized with replication user"