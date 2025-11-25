#!/usr/bin/env bash

# =============================================================================
#
#          FILE: user_lock.sh
#
#   DESCRIPTION: Library functions for locking and unlocking user accounts.
#
# =============================================================================

# --- DEPENDENCIES ---
# This script assumes that output.sh, logging.sh, and validation.sh have been sourced.

# =============================================================================
# FUNCTION: _get_user_lock_status
# DESCRIPTION:
#   Checks if a user account is locked.
# PARAMETERS:
#   $1: Username (string)
# OUTPUTS:
#   Returns a string indicating the lock status (e.g., "LK" for locked, "PS" for password set).
# =============================================================================
_get_user_lock_status() {
    local username=$1
    # The output of `passwd -S` is like: <username> <status> <date> ...
    # We only care about the status field.
    $SUDO_CMD passwd -S "$username" 2>/dev/null | awk '{print $2}'
}

# =============================================================================
# FUNCTION: lock_users
# DESCRIPTION:
#   Locks one or more user accounts. Can take a single username, a list of
#   usernames, or a file (text or JSON) containing users to lock.
# PARAMETERS:
#   $@: Usernames or options (--file, --reason)
# =============================================================================
lock_users() {
    _display_banner "Lock Users"
    
    local users_to_process=()
    local reason="No reason provided"
    local file=""
    local format="text"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --reason)
                reason="$2"
                shift 2
                ;;
            --file)
                file="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            *)
                users_to_process+=("$1")
                shift
                ;;
        esac
    done

    # Read from file if provided
    if [[ -n "$file" ]]; then
        if [[ "$format" == "json" ]]; then
            # Assumes json_input.sh is sourced and provides _parse_json_for_users
            users_to_process=($(_parse_json_for_users "$file" "lock"))
        else
            # Text file format: username:reason (reason is optional)
            while IFS= read -r line; do
                users_to_process+=("$line")
            done < "$file"
        fi
    fi

    local locked_count=0
    local skipped_count=0
    local failed_count=0
    local results_json="[]"

    for user_entry in "${users_to_process[@]}"; do
        local current_user
        local current_reason=$reason
        
        # Handle format username:reason from text files
        if [[ $user_entry == *":"* ]]; then
            current_user=$(echo "$user_entry" | cut -d: -f1)
            current_reason=$(echo "$user_entry" | cut -d: -f2-)
        else
            current_user=$user_entry
        fi

        if ! _is_valid_username "$current_user"; then
            log_error "Invalid username format: '$current_user'. Skipping."
            ((failed_count++))
            continue
        fi

        if ! _user_exists "$current_user"; then
            log_error "User '$current_user' does not exist. Skipping."
            ((failed_count++))
            # Add to JSON results
            continue
        fi

        local lock_status
        lock_status=$(_get_user_lock_status "$current_user")

        if [[ "$lock_status" == "LK" || "$lock_status" == "L" ]]; then
            log_warn "User '$current_user' is already locked. Skipping."
            ((skipped_count++))
            # Add to JSON results
        else
            if [ "$DRY_RUN" = true ]; then
                log_info "[DRY RUN] Would lock user '$current_user'."
            else
                $SUDO_CMD usermod -L "$current_user"
                log_action "Locked user '$current_user'. Reason: $current_reason"
            fi
            ((locked_count++))
            # Add to JSON results
        fi
    done

    _display_operation_summary "$locked_count" "$skipped_count" "$failed_count" "Locked"
}

# =============================================================================
# FUNCTION: unlock_users
# DESCRIPTION:
#   Unlocks one or more user accounts.
# PARAMETERS:
#   $@: Usernames or options (--file)
# =============================================================================
unlock_users() {
    _display_banner "Unlock Users"
    
    local users_to_process=()
    local file=""
    local format="text"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file)
                file="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            *)
                users_to_process+=("$1")
                shift
                ;;
        esac
    done

    # Read from file if provided
    if [[ -n "$file" ]]; then
        if [[ "$format" == "json" ]];
        then
            users_to_process=($(_parse_json_for_users "$file" "unlock"))
        else
            while IFS= read -r line; do
                users_to_process+=("$line")
            done < "$file"
        fi
    fi

    local unlocked_count=0
    local skipped_count=0
    local failed_count=0

    for username in "${users_to_process[@]}"; do
        if ! _user_exists "$username"; then
            log_error "User '$username' does not exist. Skipping."
            ((failed_count++))
            continue
        fi

        local lock_status
        lock_status=$(_get_user_lock_status "$username")

        if [[ "$lock_status" != "LK" && "$lock_status" != "L" ]]; then
            log_warn "User '$username' is already unlocked. Skipping."
            ((skipped_count++))
        else
            if [ "$DRY_RUN" = true ]; then
                log_info "[DRY RUN] Would unlock user '$username'."
            else
                $SUDO_CMD usermod -U "$username"
                log_action "Unlocked user '$username'"
            fi
            ((unlocked_count++))
        fi
    done

    _display_operation_summary "$unlocked_count" "$skipped_count" "$failed_count" "Unlocked"
}