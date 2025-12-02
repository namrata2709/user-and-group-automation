#!/bin/bash

# Log to audit file
log_audit() {
    local action="$1"
    local target="$2"
    local result="$3"
    local details="$4"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local admin_user="${SUDO_USER:-$USER}"
    local hostname=$(hostname)
    
    echo "[$timestamp] AUDIT | Admin: $admin_user | Host: $hostname | Action: $action | Target: $target | Result: $result | Details: $details" >> "$LOG_FILE"
}

# Log activity/actions
log_activity() {
    local message="$1"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] ACTIVITY | $message" >> "$LOG_FILE"
}