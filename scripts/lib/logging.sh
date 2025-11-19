#!/usr/bin/env bash
# ================================================
# Logging Module
# Version: 1.0.1
# ================================================
# Provides logging functions for audit trail
# ================================================

# log_action()
# Logs an action to the log file in human-readable format
# Args:
#   $1 - action name
#   $2 - target (user/group/system)
#   $3 - result (SUCCESS/FAILED)
#   $4 - message/details
# Returns:
#   None
log_action() {
    local action="$1"
    local target="$2"
    local result="$3"
    local message="$4"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] ACTION=$action TARGET=$target RESULT=$result MESSAGE=$message USER=$USER"
    
    # Print to console if detailed logging enabled
    if [ "${DETAILED_LOGGING}" = "yes" ]; then
        echo "$log_entry" >&2
    fi
    
    # Write to log file
    if [ -w "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
        echo "$log_entry" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# log_json()
# Logs an action to the log file in JSON format
# Args:
#   $1 - action name
#   $2 - target (user/group/system)
#   $3 - result (SUCCESS/FAILED)
#   $4 - details (JSON-safe string)
# Returns:
#   None
log_json() {
    local action="$1"
    local target="$2"
    local result="$3"
    local details="$4"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Escape details for JSON
    details=$(echo "$details" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
    local json="{\"timestamp\":\"$timestamp\",\"action\":\"$action\",\"target\":\"$target\",\"result\":\"$result\",\"user\":\"$USER\",\"details\":\"$details\"}"
    
    # Write to log file
    echo "$json" >> "$LOG_FILE" 2>/dev/null || true
}

# log_error()
# Logs an error message
# Args:
#   $1 - error message
# Returns:
#   None
log_error() {
    local message="$1"
    log_action "ERROR" "system" "FAILED" "$message"
}

# log_warning()
# Logs a warning message
# Args:
#   $1 - warning message
# Returns:
#   None
log_warning() {
    local message="$1"
    log_action "WARNING" "system" "WARNING" "$message"
}

# log_info()
# Logs an informational message
# Args:
#   $1 - info message
# Returns:
#   None
log_info() {
    local message="$1"
    log_action "INFO" "system" "SUCCESS" "$message"
}