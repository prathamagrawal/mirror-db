#!/usr/bin/env python3
"""
Pod Labeler for PostgreSQL HA Cluster

This script monitors the PostgreSQL role (primary/replica) and updates
the pod labels accordingly, enabling Kubernetes services to route traffic
to the correct pods.

Environment Variables:
    NAMESPACE: Kubernetes namespace (default: 'db')
    HOSTNAME: Pod name (automatically set by Kubernetes)
    PG_HOST: PostgreSQL host (default: 'localhost')
    PG_PORT: PostgreSQL port (default: '5432')
    PG_USER: PostgreSQL user (default: 'postgres')
    POLL_INTERVAL: Seconds between checks (default: '10')
"""

import os
import sys
import time
import logging
from typing import Optional

import psycopg2
from kubernetes import client, config
from kubernetes.client.rest import ApiException

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# Configuration from environment
NAMESPACE = os.environ.get('NAMESPACE', 'db')
POD_NAME = os.environ.get('HOSTNAME')
PG_HOST = os.environ.get('PG_HOST', 'localhost')
PG_PORT = os.environ.get('PG_PORT', '5432')
PG_USER = os.environ.get('PG_USER', 'postgres')
POLL_INTERVAL = int(os.environ.get('POLL_INTERVAL', '10'))


def get_role() -> Optional[str]:
    """
    Query PostgreSQL to determine if this node is primary or replica.
    
    Returns:
        'primary' if this is the primary node
        'replica' if this is a standby/replica node
        None if connection fails
    """
    try:
        conn = psycopg2.connect(
            user=PG_USER,
            host=PG_HOST,
            port=PG_PORT,
            connect_timeout=5
        )
        cur = conn.cursor()
        cur.execute("SELECT pg_is_in_recovery()")
        is_in_recovery = cur.fetchone()[0]
        cur.close()
        conn.close()
        return "replica" if is_in_recovery else "primary"
    except psycopg2.OperationalError as e:
        logger.warning(f"Database connection error: {e}")
        return None
    except Exception as e:
        logger.error(f"Unexpected error getting role: {e}")
        return None


def patch_label(role: str) -> bool:
    """
    Update the pod's pg-role label.
    
    Args:
        role: The role to set ('primary' or 'replica')
        
    Returns:
        True if patch succeeded, False otherwise
    """
    try:
        config.load_incluster_config()
        v1 = client.CoreV1Api()
        body = {
            "metadata": {
                "labels": {
                    "pg-role": role
                }
            }
        }
        v1.patch_namespaced_pod(POD_NAME, NAMESPACE, body)
        logger.info(f"Patched pod {POD_NAME} with label pg-role={role}")
        return True
    except ApiException as e:
        logger.error(f"Kubernetes API error patching pod label: {e.reason}")
        return False
    except Exception as e:
        logger.error(f"Failed to patch pod label: {e}")
        return False


def main():
    """Main loop: monitor PostgreSQL role and update pod labels."""
    if not POD_NAME:
        logger.error("HOSTNAME environment variable not set")
        sys.exit(1)
    
    logger.info(f"Starting pod labeler for {POD_NAME} in namespace {NAMESPACE}")
    logger.info(f"Connecting to PostgreSQL at {PG_HOST}:{PG_PORT}")
    logger.info(f"Poll interval: {POLL_INTERVAL}s")
    
    current_role = None
    consecutive_failures = 0
    max_failures = 5
    
    while True:
        detected_role = get_role()
        
        if detected_role:
            consecutive_failures = 0
            if detected_role != current_role:
                logger.info(f"Role change detected: {current_role} -> {detected_role}")
                if patch_label(detected_role):
                    current_role = detected_role
        else:
            consecutive_failures += 1
            if consecutive_failures >= max_failures:
                logger.warning(
                    f"Failed to get role {consecutive_failures} consecutive times"
                )
        
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()

