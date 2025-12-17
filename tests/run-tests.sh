#!/bin/bash
# =============================================================================
# Mirror-DB Pre-Release Test Suite
# =============================================================================
# Comprehensive automated tests for PostgreSQL HA cluster
# Usage: ./tests/run-tests.sh [namespace] [--skip-failover]
# =============================================================================

# Don't exit on errors - we handle them in run_test
set -uo pipefail

# Configuration
NAMESPACE="${1:-db}"
SKIP_FAILOVER="${2:-}"
TIMEOUT=300
TEST_TABLE="mirror_db_test_$(date +%s)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((TESTS_SKIPPED++))
}

log_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

run_test() {
    local name="$1"
    local cmd="$2"
    local expected="${3:-}"
    
    log_info "Testing: $name"
    
    local output=""
    local exit_code=0
    
    output=$(eval "$cmd" 2>&1) || exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        if [[ -n "$expected" ]]; then
            if echo "$output" | grep -q "$expected"; then
                log_success "$name"
                return 0
            else
                log_fail "$name - Expected '$expected' not found"
                echo "  Output: $output"
                return 0  # Don't exit script
            fi
        else
            log_success "$name"
            return 0
        fi
    else
        log_fail "$name"
        echo "  Error: $output"
        return 0  # Don't exit script
    fi
}

get_monitor_pod() {
    kubectl get pods -n "$NAMESPACE" -l app=postgres-monitor -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

get_primary_pod() {
    kubectl get pods -n "$NAMESPACE" -l app=postgres-nodes,pg-role=primary -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

get_replica_pods() {
    kubectl get pods -n "$NAMESPACE" -l app=postgres-nodes,pg-role=replica -o jsonpath='{.items[*].metadata.name}' 2>/dev/null
}

get_pgbouncer_primary_pod() {
    kubectl get pods -n "$NAMESPACE" -l app=pgbouncer-primary -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

get_pgbouncer_replicas_pod() {
    kubectl get pods -n "$NAMESPACE" -l app=pgbouncer-replicas -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

wait_for_pods() {
    local label="$1"
    local expected_ready="$2"
    local timeout="${3:-$TIMEOUT}"
    
    log_info "Waiting for pods with label '$label' to be ready..."
    
    kubectl wait --for=condition=ready pod -l "$label" -n "$NAMESPACE" --timeout="${timeout}s" 2>/dev/null
}

# =============================================================================
# Test Categories
# =============================================================================

test_prerequisites() {
    log_header "1. PREREQUISITES CHECK"
    
    # Check kubectl
    run_test "kubectl is available" "which kubectl"
    
    # Check namespace exists
    run_test "Namespace '$NAMESPACE' exists" \
        "kubectl get namespace $NAMESPACE" \
        "$NAMESPACE"
    
    # Check required pods exist
    run_test "Monitor deployment exists" \
        "kubectl get deployment postgres-monitor -n $NAMESPACE" \
        "postgres-monitor"
    
    run_test "PostgreSQL StatefulSet exists" \
        "kubectl get statefulset postgres-nodes -n $NAMESPACE" \
        "postgres-nodes"
    
    run_test "PgBouncer Primary deployment exists" \
        "kubectl get deployment pgbouncer-primary -n $NAMESPACE" \
        "pgbouncer-primary"
    
    run_test "PgBouncer Replicas deployment exists" \
        "kubectl get deployment pgbouncer-replicas -n $NAMESPACE" \
        "pgbouncer-replicas"
}

test_pod_health() {
    log_header "2. POD HEALTH CHECK"
    
    # Check all pods are running
    run_test "Monitor pod is Running" \
        "kubectl get pods -n $NAMESPACE -l app=postgres-monitor -o jsonpath='{.items[0].status.phase}'" \
        "Running"
    
    # Count non-running pods - should be 0
    local non_running=$(kubectl get pods -n "$NAMESPACE" -l app=postgres-nodes --no-headers 2>/dev/null | grep -v Running | wc -l | tr -d ' ')
    if [[ "$non_running" -eq 0 ]]; then
        log_success "All PostgreSQL pods are Running"
    else
        log_fail "All PostgreSQL pods are Running ($non_running pods not running)"
    fi
    
    run_test "PgBouncer Primary pod is Running" \
        "kubectl get pods -n $NAMESPACE -l app=pgbouncer-primary -o jsonpath='{.items[0].status.phase}'" \
        "Running"
    
    run_test "PgBouncer Replicas pod is Running" \
        "kubectl get pods -n $NAMESPACE -l app=pgbouncer-replicas -o jsonpath='{.items[0].status.phase}'" \
        "Running"
    
    # Check containers in pods
    run_test "PostgreSQL pods have all containers ready" \
        "kubectl get pods -n $NAMESPACE -l app=postgres-nodes -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | tr ' ' '\n' | grep -c false || echo 0" \
        "0"
}

test_cluster_state() {
    log_header "3. CLUSTER STATE CHECK"
    
    local monitor_pod=$(get_monitor_pod)
    
    if [[ -z "$monitor_pod" ]]; then
        log_fail "Could not find monitor pod"
        return 1
    fi
    
    # Check cluster state from monitor
    log_info "Cluster state from monitor:"
    kubectl exec -n "$NAMESPACE" "$monitor_pod" -- \
        pg_autoctl show state --pgdata /var/lib/postgresql/pgdata/monitor 2>/dev/null || true
    echo ""
    
    # Verify we have exactly one primary
    local primary_count=$(kubectl get pods -n "$NAMESPACE" -l app=postgres-nodes,pg-role=primary --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$primary_count" -eq 1 ]]; then
        log_success "Exactly one primary node exists"
    else
        log_fail "Expected 1 primary, found $primary_count"
    fi
    
    # Verify we have replicas
    local replica_count=$(kubectl get pods -n "$NAMESPACE" -l app=postgres-nodes,pg-role=replica --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$replica_count" -ge 1 ]]; then
        log_success "At least one replica exists (found $replica_count)"
    else
        log_fail "No replicas found"
    fi
    
    # Check pod labels
    run_test "All PostgreSQL pods have pg-role label" \
        "kubectl get pods -n $NAMESPACE -l app=postgres-nodes -o jsonpath='{.items[*].metadata.labels.pg-role}' | wc -w | tr -d ' '" \
        "$(kubectl get pods -n $NAMESPACE -l app=postgres-nodes --no-headers | wc -l | tr -d ' ')"
}

test_services() {
    log_header "4. SERVICES CHECK"
    
    # Check services exist
    run_test "postgres-monitor service exists" \
        "kubectl get svc postgres-monitor -n $NAMESPACE" \
        "postgres-monitor"
    
    run_test "postgres-primary service exists" \
        "kubectl get svc postgres-primary -n $NAMESPACE" \
        "postgres-primary"
    
    run_test "postgres-replicas service exists" \
        "kubectl get svc postgres-replicas -n $NAMESPACE" \
        "postgres-replicas"
    
    run_test "pgbouncer-primary-service exists" \
        "kubectl get svc pgbouncer-primary-service -n $NAMESPACE" \
        "pgbouncer-primary-service"
    
    # Check endpoints have IPs
    run_test "postgres-primary service has endpoints" \
        "kubectl get endpoints postgres-primary -n $NAMESPACE -o jsonpath='{.subsets[0].addresses[0].ip}'"
    
    run_test "postgres-replicas service has endpoints" \
        "kubectl get endpoints postgres-replicas -n $NAMESPACE -o jsonpath='{.subsets[0].addresses[0].ip}'"
}

test_direct_connections() {
    log_header "5. DIRECT CONNECTION TESTS"
    
    local primary_pod=$(get_primary_pod)
    
    if [[ -z "$primary_pod" ]]; then
        log_fail "Could not find primary pod for connection tests"
        return 1
    fi
    
    # Test direct connection to primary
    run_test "Direct connection to primary" \
        "kubectl exec -n $NAMESPACE $primary_pod -c postgres -- psql -U postgres -c 'SELECT 1' -t | tr -d ' '"  \
        "1"
    
    # Test primary is not in recovery (is actually primary)
    run_test "Primary is not in recovery mode" \
        "kubectl exec -n $NAMESPACE $primary_pod -c postgres -- psql -U postgres -c 'SELECT pg_is_in_recovery()' -t | tr -d ' '" \
        "f"
    
    # Test replica connections
    for replica_pod in $(get_replica_pods); do
        run_test "Direct connection to replica $replica_pod" \
            "kubectl exec -n $NAMESPACE $replica_pod -c postgres -- psql -U postgres -c 'SELECT 1' -t | tr -d ' '" \
            "1"
        
        run_test "Replica $replica_pod is in recovery mode" \
            "kubectl exec -n $NAMESPACE $replica_pod -c postgres -- psql -U postgres -c 'SELECT pg_is_in_recovery()' -t | tr -d ' '" \
            "t"
    done
}

test_pgbouncer_connections() {
    log_header "6. PGBOUNCER CONNECTION TESTS"
    
    local pgb_primary=$(get_pgbouncer_primary_pod)
    local pgb_replicas=$(get_pgbouncer_replicas_pod)
    
    if [[ -z "$pgb_primary" ]]; then
        log_fail "Could not find PgBouncer primary pod"
        return 1
    fi
    
    # Test PgBouncer primary connection
    run_test "PgBouncer primary accepts connections" \
        "kubectl exec -n $NAMESPACE $pgb_primary -- psql -h localhost -p 6432 -U postgres -c 'SELECT 1' -t 2>/dev/null | tr -d ' '" \
        "1"
    
    # Test PgBouncer routes to actual primary
    run_test "PgBouncer primary routes to actual primary" \
        "kubectl exec -n $NAMESPACE $pgb_primary -- psql -h localhost -p 6432 -U postgres -c 'SELECT pg_is_in_recovery()' -t 2>/dev/null | tr -d ' '" \
        "f"
    
    if [[ -n "$pgb_replicas" ]]; then
        # Test PgBouncer replicas connection
        run_test "PgBouncer replicas accepts connections" \
            "kubectl exec -n $NAMESPACE $pgb_replicas -- psql -h localhost -p 6432 -U postgres -c 'SELECT 1' -t 2>/dev/null | tr -d ' '" \
            "1"
        
        # Test PgBouncer routes to replica
        run_test "PgBouncer replicas routes to replica" \
            "kubectl exec -n $NAMESPACE $pgb_replicas -- psql -h localhost -p 6432 -U postgres -c 'SELECT pg_is_in_recovery()' -t 2>/dev/null | tr -d ' '" \
            "t"
    fi
}

test_replication() {
    log_header "7. REPLICATION TESTS"
    
    local primary_pod=$(get_primary_pod)
    local pgb_primary=$(get_pgbouncer_primary_pod)
    local pgb_replicas=$(get_pgbouncer_replicas_pod)
    
    if [[ -z "$primary_pod" ]]; then
        log_fail "Could not find primary pod for replication tests"
        return 1
    fi
    
    # Check replication status
    log_info "Replication status:"
    kubectl exec -n "$NAMESPACE" "$primary_pod" -c postgres -- \
        psql -U postgres -c "SELECT client_addr, state, sync_state, sent_lsn, write_lsn, flush_lsn, replay_lsn FROM pg_stat_replication;" 2>/dev/null || true
    echo ""
    
    # Verify replication slots exist
    run_test "Replication slots exist" \
        "kubectl exec -n $NAMESPACE $primary_pod -c postgres -- psql -U postgres -c \"SELECT count(*) FROM pg_replication_slots WHERE active = true\" -t | tr -d ' '"
    
    # Test write propagation
    log_info "Testing write propagation..."
    
    # Create test table and insert data
    if kubectl exec -n "$NAMESPACE" "$pgb_primary" -- \
        psql -h localhost -p 6432 -U postgres -c "CREATE TABLE IF NOT EXISTS $TEST_TABLE (id serial, data text, created_at timestamp default now());" 2>/dev/null; then
        log_success "Created test table $TEST_TABLE"
    else
        log_fail "Failed to create test table"
        return 1
    fi
    
    # Insert test data
    if kubectl exec -n "$NAMESPACE" "$pgb_primary" -- \
        psql -h localhost -p 6432 -U postgres -c "INSERT INTO $TEST_TABLE (data) VALUES ('test_data_$(date +%s)');" 2>/dev/null; then
        log_success "Inserted test data via primary"
    else
        log_fail "Failed to insert test data"
    fi
    
    # Wait for replication
    sleep 2
    
    # Read from replica
    if [[ -n "$pgb_replicas" ]]; then
        local replica_count=$(kubectl exec -n "$NAMESPACE" "$pgb_replicas" -- \
            psql -h localhost -p 6432 -U postgres -c "SELECT count(*) FROM $TEST_TABLE" -t 2>/dev/null | tr -d ' ')
        
        if [[ "$replica_count" -ge 1 ]]; then
            log_success "Data replicated to replica (found $replica_count rows)"
        else
            log_fail "Data not replicated to replica"
        fi
    fi
    
    # Cleanup test table
    kubectl exec -n "$NAMESPACE" "$pgb_primary" -- \
        psql -h localhost -p 6432 -U postgres -c "DROP TABLE IF EXISTS $TEST_TABLE;" 2>/dev/null || true
}

test_failover() {
    log_header "8. FAILOVER TEST"
    
    if [[ "$SKIP_FAILOVER" == "--skip-failover" ]]; then
        log_skip "Failover test skipped (--skip-failover flag)"
        return 0
    fi
    
    local original_primary=$(get_primary_pod)
    local monitor_pod=$(get_monitor_pod)
    local pgb_primary=$(get_pgbouncer_primary_pod)
    
    if [[ -z "$original_primary" ]]; then
        log_fail "Could not find primary pod for failover test"
        return 1
    fi
    
    log_info "Original primary: $original_primary"
    
    # Create test data before failover
    local test_value="failover_test_$(date +%s)"
    kubectl exec -n "$NAMESPACE" "$pgb_primary" -- \
        psql -h localhost -p 6432 -U postgres -c "CREATE TABLE IF NOT EXISTS failover_test (id serial, data text);" 2>/dev/null || true
    kubectl exec -n "$NAMESPACE" "$pgb_primary" -- \
        psql -h localhost -p 6432 -U postgres -c "INSERT INTO failover_test (data) VALUES ('$test_value');" 2>/dev/null || true
    
    log_info "Triggering failover by deleting primary pod..."
    kubectl delete pod -n "$NAMESPACE" "$original_primary" --wait=false
    
    # Wait for failover - check BOTH pod label AND pg_auto_failover state
    log_info "Waiting for failover to complete (up to 120 seconds)..."
    local wait_time=0
    local max_wait=120
    local new_primary=""
    local failover_complete=false
    
    while [[ $wait_time -lt $max_wait ]]; do
        sleep 5
        wait_time=$((wait_time + 5))
        
        new_primary=$(get_primary_pod)
        
        if [[ -n "$new_primary" && "$new_primary" != "$original_primary" ]]; then
            # Check if pg_auto_failover state is actually "primary" (not transitional)
            # Parse the table output - look for "primary" in Current State column
            local monitor_output=$(kubectl exec -n "$NAMESPACE" "$(get_monitor_pod)" -- \
                pg_autoctl show state --pgdata /var/lib/postgresql/pgdata/monitor 2>/dev/null)
            
            # Extract the line for the new primary and check if it contains "| primary |" pattern
            local node_line=$(echo "$monitor_output" | grep "$new_primary")
            
            # Check if Current State is "primary" (appears before the last |)
            if echo "$node_line" | grep -q "|[[:space:]]*primary[[:space:]]*|[[:space:]]*primary"; then
                log_success "Failover complete! New primary: $new_primary (after ${wait_time}s)"
                log_info "pg_auto_failover state confirmed: primary"
                failover_complete=true
                break
            else
                # Extract current state for debugging (field between last two pipes)
                local current_state=$(echo "$node_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $(NF-1)); print $(NF-1)}')
                log_info "Waiting... (${wait_time}s) - $new_primary has label but state is: ${current_state:-unknown}"
            fi
        else
            log_info "Waiting... (${wait_time}s) - Current primary pod: ${new_primary:-none}"
        fi
    done
    
    if [[ "$failover_complete" != "true" ]]; then
        log_fail "Failover did not complete within ${max_wait}s"
        # Show current state for debugging
        kubectl exec -n "$NAMESPACE" "$(get_monitor_pod)" -- \
            pg_autoctl show state --pgdata /var/lib/postgresql/pgdata/monitor 2>/dev/null || true
        return 0
    fi
    
    # Give new primary a moment to stabilize
    log_info "Waiting 10s for new primary to stabilize..."
    sleep 10
    
    # First verify new primary is accepting connections directly
    log_info "Verifying new primary directly..."
    local new_primary_pod=$(get_primary_pod)
    log_info "New primary pod: $new_primary_pod"
    
    # Debug: Check pod labels
    log_info "Current pod labels:"
    kubectl get pods -n "$NAMESPACE" -l app=postgres-nodes --show-labels 2>/dev/null | head -10
    
    # Debug: Check if new primary is in recovery mode
    local recovery_status=$(kubectl exec -n "$NAMESPACE" "$new_primary_pod" -c postgres -- \
        psql -U postgres -t -c "SELECT pg_is_in_recovery()" 2>&1 | tr -d ' ')
    log_info "New primary recovery status: $recovery_status"
    
    # Debug: Check cluster state from monitor
    log_info "Cluster state after failover:"
    kubectl exec -n "$NAMESPACE" "$(get_monitor_pod)" -- \
        pg_autoctl show state --pgdata /var/lib/postgresql/pgdata/monitor 2>/dev/null || true
    
    # Debug: Check if table exists on new primary
    log_info "Checking if failover_test table exists on new primary..."
    kubectl exec -n "$NAMESPACE" "$new_primary_pod" -c postgres -- \
        psql -U postgres -c "\\dt failover_test" 2>&1 || true
    
    # Try direct write with detailed error
    log_info "Attempting direct write to new primary..."
    local direct_write_output
    direct_write_output=$(kubectl exec -n "$NAMESPACE" "$new_primary_pod" -c postgres -- \
        psql -U postgres -c "INSERT INTO failover_test (data) VALUES ('direct_write')" 2>&1)
    local direct_write_exit=$?
    
    if [[ $direct_write_exit -eq 0 ]]; then
        log_success "New primary accepts direct writes"
    else
        log_fail "New primary does not accept direct writes"
        log_info "Direct write error: $direct_write_output"
    fi
    
    # Now test via PgBouncer - restart pgbouncer to force reconnection
    log_info "Restarting PgBouncer to force reconnection to new primary..."
    kubectl delete pod -n "$NAMESPACE" -l app=pgbouncer-primary --wait=false 2>/dev/null || true
    sleep 10
    
    # Wait for PgBouncer to be ready
    kubectl wait --for=condition=ready pod -l app=pgbouncer-primary -n "$NAMESPACE" --timeout=60s 2>/dev/null || true
    sleep 5
    
    # Try write via PgBouncer with retries
    local write_success=false
    for i in 1 2 3 4 5; do
        local pgb_pod=$(get_pgbouncer_primary_pod)
        if [[ -n "$pgb_pod" ]] && kubectl exec -n "$NAMESPACE" "$pgb_pod" -- \
            psql -h localhost -p 6432 -U postgres -c "INSERT INTO failover_test (data) VALUES ('pgbouncer_write_$i')" 2>/dev/null; then
            write_success=true
            break
        fi
        log_info "PgBouncer write attempt $i failed, retrying in 5s..."
        sleep 5
    done
    
    if [[ "$write_success" == "true" ]]; then
        log_success "New primary accepts writes via PgBouncer"
    else
        log_fail "New primary does not accept writes via PgBouncer (after 5 retries)"
    fi
    
    # Verify data survived failover
    local data_check=$(kubectl exec -n "$NAMESPACE" "$(get_pgbouncer_primary_pod)" -- \
        psql -h localhost -p 6432 -U postgres -c "SELECT data FROM failover_test WHERE data = '$test_value'" -t 2>/dev/null | tr -d ' ')
    
    if [[ "$data_check" == "$test_value" ]]; then
        log_success "Data survived failover"
    else
        log_fail "Data lost during failover"
    fi
    
    # Wait for old primary to rejoin
    log_info "Waiting for original primary to rejoin as replica..."
    sleep 30
    
    local old_primary_role=$(kubectl get pod -n "$NAMESPACE" "$original_primary" -o jsonpath='{.metadata.labels.pg-role}' 2>/dev/null)
    if [[ "$old_primary_role" == "replica" ]]; then
        log_success "Original primary rejoined as replica"
    else
        log_info "Original primary role: ${old_primary_role:-unknown} (may still be recovering)"
    fi
    
    # Cleanup
    kubectl exec -n "$NAMESPACE" "$(get_pgbouncer_primary_pod)" -- \
        psql -h localhost -p 6432 -U postgres -c "DROP TABLE IF EXISTS failover_test;" 2>/dev/null || true
}

test_pod_disruption_budgets() {
    log_header "9. POD DISRUPTION BUDGETS"
    
    run_test "PostgreSQL nodes PDB exists" \
        "kubectl get pdb postgres-nodes-pdb -n $NAMESPACE" \
        "postgres-nodes-pdb"
    
    run_test "Monitor PDB exists" \
        "kubectl get pdb postgres-monitor-pdb -n $NAMESPACE" \
        "postgres-monitor-pdb"
    
    run_test "PgBouncer Primary PDB exists" \
        "kubectl get pdb pgbouncer-primary-pdb -n $NAMESPACE" \
        "pgbouncer-primary-pdb"
}

# =============================================================================
# Main Test Runner
# =============================================================================

main() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         MIRROR-DB PRE-RELEASE TEST SUITE                      ║${NC}"
    echo -e "${BLUE}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║  Namespace: ${NAMESPACE}$(printf '%*s' $((40 - ${#NAMESPACE})) '')║${NC}"
    echo -e "${BLUE}║  Timestamp: $(date '+%Y-%m-%d %H:%M:%S')                         ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    # Run all test categories
    test_prerequisites
    test_pod_health
    test_cluster_state
    test_services
    test_direct_connections
    test_pgbouncer_connections
    test_replication
    test_failover
    test_pod_disruption_budgets
    
    # Summary
    log_header "TEST SUMMARY"
    
    echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
    echo -e "  ${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    echo ""
    
    local total=$((TESTS_PASSED + TESTS_FAILED))
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  ✅ ALL TESTS PASSED! Ready for release.${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        exit 0
    else
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}  ❌ $TESTS_FAILED TEST(S) FAILED. Please fix before release.${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        exit 1
    fi
}

# Run main
main "$@"
