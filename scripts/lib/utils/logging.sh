#!/usr/bin/env bash
# ==============================================================================
#
#          FILE: logging.sh
#
#         USAGE: source logging.sh
#
#   DESCRIPTION: A comprehensive logging library for recording script
#                operations. It supports multiple log levels (INFO, WARN, ERROR,
#                DEBUG), structured human-readable output, and JSON output for
#                easy parsing by other tools.
#
#       OPTIONS: ---
#  REQUIREMENTS: bash, coreutils, date
#          BUGS: ---\
#         NOTES: This library is essential for auditing, debugging, and
#                tracking all actions performed by the user management scripts.
#       AUTHOR: Your Name, your.email@example.com
# ORGANIZATION: Your Company
#      CREATED: YYYY-MM-DD
#     REVISION: 1.2.0
#
# ==============================================================================

# ==============================================================================\n# SECTION: CORE LOGGING FUNCTIONS\n# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: log_action()
#
# DESCRIPTION:
#   The primary logging function for human-readable output. It records a
#   timestamped entry detailing the action performed, the target of the action,
#   the result, and a descriptive message. This creates a clear and auditable
#   trail of all script operations.
#
# ARGUMENTS:
#   $1: action - The type of action being performed (e.g., "CREATE_USER").
#   $2: target - The entity being acted upon (e.g., a username, group name,
#       or "system").
#   $3: result - The outcome of the action (e.g., "SUCCESS", "FAILED",
#       "SKIPPED").
#   $4: message - A detailed message describing the operation and its outcome.
#
# GLOBALS:
#   LOG_FILE (read): The path to the log file where the entry will be written.
#   USER (read): The system user executing the script.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# FUNCTION: log_json()
#
# DESCRIPTION:
#   Logs an action in a structured JSON format. This is designed for integration
#   with automated log analysis tools, monitoring systems, or other scripts
#   that can easily parse JSON. Each log entry is a single-line JSON object.
#
# ARGUMENTS:
#   $1: action - The type of action (e.g., "create_user").
#   $2: target - The entity being acted upon.
#   $3: result - The outcome of the action.
#   $4: details - A JSON-safe string containing additional structured data.
#
# GLOBALS:
#   LOG_FILE (read): The path to the log file.
#   USER (read): The system user executing the script.
# ------------------------------------------------------------------------------
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


# ------------------------------------------------------------------------------
# FUNCTION: log_error()
#
# DESCRIPTION:
#   A convenience wrapper for logging a system-level error. It standardizes
#   the format for error messages, making them easy to spot in the logs.
#
# ARGUMENTS:
#   $1: message - The error message to log.
# ------------------------------------------------------------------------------
log_error() {
    local message="$1"
    log_action "ERROR" "system" "FAILED" "$message"
}

# ------------------------------------------------------------------------------
# FUNCTION: log_warning()
#
# DESCRIPTION:
#   A convenience wrapper for logging a warning. Warnings indicate that an
#   operation completed but encountered a non-critical issue that may
#   require attention.
#
# ARGUMENTS:
#   $1: message - The warning message to log.
# ------------------------------------------------------------------------------
log_warning() {
    local message="$1"
    log_action "WARNING" "system" "WARNING" "$message"
}

# ------------------------------------------------------------------------------
# FUNCTION: log_info()
#
# DESCRIPTION:
#   A convenience wrapper for logging general informational messages. These are
#   used to track the script's progress and major state changes.
#
# ARGUMENTS:
#   $1: message - The informational message to log.
# ------------------------------------------------------------------------------
log_info() {
    local message="$1"
    log_action "INFO" "system" "SUCCESS" "$message"
}

# ------------------------------------------------------------------------------
# FUNCTION: log_debug()
#
# DESCRIPTION:
#   Logs a debug message only if the DEBUG environment variable is set to "true".
#   This is used for verbose, detailed output that is helpful for developers
#   during troubleshooting but is too noisy for production use.
#
# ARGUMENTS:
#   $1: message - The debug message to log.
#
# GLOBALS:
#   DEBUG (read): The flag that enables or disables debug logging.
# ------------------------------------------------------------------------------
log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "[DEBUG $(date '+%H:%M:%S')] $1" >&2
    fi
}