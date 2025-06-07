#!/bin/bash
set -e

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Ensure we have write permissions to data directory
if [ ! -w /var/lib/postgresql/data ]; then
    log "ERROR: Data directory not writable, exiting..."
    exit 1
fi

# Validate required environment variables
if [ -z "$REPLICA_TYPE" ]; then
    log "ERROR: REPLICA_TYPE environment variable is required (sync|async)"
    exit 1
fi

if [ "$REPLICA_TYPE" != "sync" ] && [ "$REPLICA_TYPE" != "async" ]; then
    log "ERROR: REPLICA_TYPE must be either 'sync' or 'async'"
    exit 1
fi

log "Starting PostgreSQL replica setup for $REPLICA_TYPE replica"

# Copy and make script executable in writable location
if [ -f /tmp/init-replica.sh ]; then
    log "Copying initialization script to writable location"
    cp /tmp/init-replica.sh /tmp/init-replica-exec.sh
    chmod +x /tmp/init-replica-exec.sh

    # Run initialization script (it handles PostgreSQL startup)
    log "Executing initialization script for $REPLICA_TYPE replica"
    exec /tmp/init-replica-exec.sh
else
    log "ERROR: Initialization script not found at /tmp/init-replica.sh"
    exit 1
fi