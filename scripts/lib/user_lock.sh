#!/usr/bin/env bash
# ================================================
# User Lock Module - REFACTORED
# Version: 2.0.0
# ================================================
# Single lock/unlock logic, multiple format parsers
# ================================================

# ============================================
# CORE FUNCTION - Single user lock logic
# ============================================
# lock_single_user()
# Locks a single user account
# Args:
#   $1 - username (required)
#   $2 - reason (optional)
# Returns:
#   0 on success, 1 on failure
lock_single_user() {
    local username="$1"
    local reason="${2:-No reason provided}"
    
    # Validate username
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        log_action "lock_user" "$username" "FAILED" "User not found"
        return 1
    fi
    
    # Check if already locked
    if passwd -S "$username" 2>/dev/null | grep -q " LK "; then
        echo "${ICON_WARNING} User '$username' is already locked"
        log_action "lock_user" "$username" "SKIPPED" "Already locked"
        return 1
    fi
    
    # DRY-RUN mode
    if [ "$DRY_RUN" = true ]; then
        echo "${ICON_SEARCH} [DRY-RUN] Would lock user: $username"
        [ -n "$reason" ] && echo "   - Reason: $reason"
        return 0
    fi
    
    # Lock user
    echo "${ICON_LOCK} Locking user: $username"
    echo "   Reason: $reason"
    
    if sudo passwd -l "$username" &>/dev/null; then
        echo "   ${ICON_SUCCESS} User locked successfully"
        
        # Log with reason
        log_action "lock_user" "$username" "SUCCESS" "Reason: $reason"
        
        echo ""
        echo "User '$username' is now locked:"
        echo "  - Cannot login via SSH or terminal"
        echo "  - Existing sessions remain active"
        echo "  - All data preserved"
        echo "  - Can be unlocked: ./user.sh --unlock user --name $username"
        
        return 0
    else
        echo "   ${ICON_ERROR} Failed to lock user"
        log_action "lock_user" "$username" "FAILED" "passwd command failed"
        return 1
    fi
}

# ============================================
# CORE FUNCTION - Single user unlock logic
# ============================================
# unlock_single_user()
# Unlocks a single user account
# Args:
#   $1 - username (required)
# Returns:
#   0 on success, 1 on failure
unlock_single_user() {
    local username="$1"
    
    # Validate username
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        log_action "unlock_user" "$username" "FAILED" "User not found"
        return 1
    fi
    
    # Check if already unlocked
    if ! passwd -S "$username" 2>/dev/null | grep -q " LK "; then
        echo "${ICON_WARNING} User '$username' is not locked"
        log_action "unlock_user" "$username" "SKIPPED" "Not locked"
        return 1
    fi
    
    # DRY-RUN mode
    if [ "$DRY_RUN" = true ]; then
        echo "${ICON_SEARCH} [DRY-RUN] Would unlock user: $username"
        return 0
    fi
    
    # Unlock user
    echo "${ICON_UNLOCK} Unlocking user: $username"
    
    if sudo passwd -u "$username" &>/dev/null; then
        echo "   ${ICON_SUCCESS} User unlocked successfully"
        log_action "unlock_user" "$username" "SUCCESS" "User unlocked"
        
        echo ""
        echo "User '$username' is now unlocked and can login"
        
        return 0
    else
        echo "   ${ICON_ERROR} Failed to unlock user"
        log_action "unlock_user" "$username" "FAILED" "passwd command failed"
        return 1
    fi
}

# ============================================
# PARSER: Text File Format - Lock
# ============================================
# parse_lock_from_text()
# Parses text file and locks users
# Format: username:reason (reason is optional)
# Args:
#   $1 - text file path
#   $2 - global reason (optional, used if no reason in file)
# Returns:
#   Summary counts
parse_lock_from_text() {
    local lock_file="$1"
    local global_reason="${2:-Bulk lock operation}"
    
    if [[ ! -f "$lock_file" ]]; then
        echo "${ICON_ERROR} Lock file not found: $lock_file"
        return 1
    fi
    
    local count=0 locked=0 skipped=0 failed=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        count=$((count + 1))
        
        # Parse line: username:reason (or just username)
        local username reason
        if [[ "$line" =~ : ]]; then
            username=$(echo "$line" | cut -d':' -f1 | xargs)
            reason=$(echo "$line" | cut -d':' -f2- | xargs)
        else
            username=$(echo "$line" | xargs)
            reason="$global_reason"
        fi
        
        # Call core function
        if lock_single_user "$username" "$reason"; then
            ((locked++))
        else
            if passwd -S "$username" 2>/dev/null | grep -q " LK "; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < "$lock_file"
    
    echo "=========================================="
    echo "Summary:"
    echo "  Total processed: $count"
    echo "  Locked: $locked"
    echo "  Skipped: $skipped"
    echo "  Failed: $failed"
    echo "=========================================="
    
    return 0
}

# ============================================
# PARSER: Text File Format - Unlock
# ============================================
# parse_unlock_from_text()
# Parses text file and unlocks users
# Format: username (one per line)
# Args:
#   $1 - text file path
# Returns:
#   Summary counts
parse_unlock_from_text() {
    local unlock_file="$1"
    
    if [[ ! -f "$unlock_file" ]]; then
        echo "${ICON_ERROR} Unlock file not found: $unlock_file"
        return 1
    fi
    
    local count=0 unlocked=0 skipped=0 failed=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        local username="$line"
        count=$((count + 1))
        
        # Call core function
        if unlock_single_user "$username"; then
            ((unlocked++))
        else
            if ! passwd -S "$username" 2>/dev/null | grep -q " LK "; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < "$unlock_file"
    
    echo "=========================================="
    echo "Summary:"
    echo "  Total processed: $count"
    echo "  Unlocked: $unlocked"
    echo "  Skipped: $skipped"
    echo "  Failed: $failed"
    echo "=========================================="
    
    return 0
}

# ============================================
# PARSER: JSON Format - Lock
# ============================================
# parse_lock_from_json()
# Parses JSON file and locks users
# Args:
#   $1 - JSON file path
# Returns:
#   Summary counts
parse_lock_from_json() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        echo "${ICON_ERROR} JSON file not found: $json_file"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "${ICON_ERROR} jq not installed. Install with: sudo apt install jq"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$json_file" 2>/dev/null; then
        echo "${ICON_ERROR} Invalid JSON format: $json_file"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq -e '.locks' "$json_file" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Invalid JSON structure - missing 'locks' array"
        return 1
    fi
    
    local count=0 locked=0 skipped=0 failed=0
    local start_time=$(date +%s)
    
    # Parse each lock from JSON
    while IFS= read -r lock_json; do
        ((count++))
        
        # Extract fields from JSON
        local username=$(echo "$lock_json" | jq -r '.username')
        local reason=$(echo "$lock_json" | jq -r '.reason // "Locked via JSON"')
        
        # Call core function
        if lock_single_user "$username" "$reason"; then
            ((locked++))
        else
            if passwd -S "$username" 2>/dev/null | grep -q " LK "; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < <(jq -c '.locks[]' "$json_file" 2>/dev/null)
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "=========================================="
    echo "Summary:"
    echo "  Total processed: $count"
    echo "  Locked: $locked"
    echo "  Skipped: $skipped"
    echo "  Failed: $failed"
    echo "  Duration: ${duration}s"
    echo "=========================================="
    
    return 0
}

# ============================================
# PARSER: JSON Format - Unlock
# ============================================
# parse_unlock_from_json()
# Parses JSON file and unlocks users
# Args:
#   $1 - JSON file path
# Returns:
#   Summary counts
parse_unlock_from_json() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        echo "${ICON_ERROR} JSON file not found: $json_file"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "${ICON_ERROR} jq not installed. Install with: sudo apt install jq"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$json_file" 2>/dev/null; then
        echo "${ICON_ERROR} Invalid JSON format: $json_file"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq -e '.unlocks' "$json_file" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Invalid JSON structure - missing 'unlocks' array"
        return 1
    fi
    
    local count=0 unlocked=0 skipped=0 failed=0
    local start_time=$(date +%s)
    
    # Parse each unlock from JSON
    while IFS= read -r unlock_json; do
        ((count++))
        
        # Extract username from JSON
        local username=$(echo "$unlock_json" | jq -r '.username')
        
        # Call core function
        if unlock_single_user "$username"; then
            ((unlocked++))
        else
            if ! passwd -S "$username" 2>/dev/null | grep -q " LK "; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < <(jq -c '.unlocks[]' "$json_file" 2>/dev/null)
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "=========================================="
    echo "Summary:"
    echo "  Total processed: $count"
    echo "  Unlocked: $unlocked"
    echo "  Skipped: $skipped"
    echo "  Failed: $failed"
    echo "  Duration: ${duration}s"
    echo "=========================================="
    
    return 0
}

# ============================================
# PUBLIC INTERFACE - Lock users
# ============================================
# lock_users()
# Main entry point for locking - detects format and routes to parser
# Args:
#   $1 - file path (optional, if not provided uses single user mode)
#   $2 - format (optional: "text", "json", auto-detect if not provided)
#   $3 - global reason (optional, for text files without reasons)
# Returns:
#   0 on success, 1 on failure
lock_users() {
    local lock_file="$1"
    local format="${2:-auto}"
    local global_reason="${3:-Bulk lock operation}"
    
    if [[ ! -f "$lock_file" ]]; then
        echo "${ICON_ERROR} Lock file not found: $lock_file"
        return 1
    fi
    
    # Auto-detect format if not specified
    if [ "$format" = "auto" ]; then
        if [[ "$lock_file" =~ \.json$ ]]; then
            format="json"
        else
            format="text"
        fi
    fi
    
    echo "=========================================="
    echo "Locking Users from: $lock_file"
    echo "Format: $format"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    [ -n "$global_reason" ] && [ "$format" = "text" ] && echo "Default Reason: $global_reason"
    echo "=========================================="
    echo ""
    
    # Route to appropriate parser
    case "$format" in
        json)
            parse_lock_from_json "$lock_file"
            ;;
        text|txt)
            parse_lock_from_text "$lock_file" "$global_reason"
            ;;
        *)
            echo "${ICON_ERROR} Unknown format: $format"
            echo "Supported formats: text, json"
            return 1
            ;;
    esac
}

# ============================================
# PUBLIC INTERFACE - Unlock users
# ============================================
# unlock_users()
# Main entry point for unlocking - detects format and routes to parser
# Args:
#   $1 - file path (optional, if not provided uses single user mode)
#   $2 - format (optional: "text", "json", auto-detect if not provided)
# Returns:
#   0 on success, 1 on failure
unlock_users() {
    local unlock_file="$1"
    local format="${2:-auto}"
    
    if [[ ! -f "$unlock_file" ]]; then
        echo "${ICON_ERROR} Unlock file not found: $unlock_file"
        return 1
    fi
    
    # Auto-detect format if not specified
    if [ "$format" = "auto" ]; then
        if [[ "$unlock_file" =~ \.json$ ]]; then
            format="json"
        else
            format="text"
        fi
    fi
    
    echo "=========================================="
    echo "Unlocking Users from: $unlock_file"
    echo "Format: $format"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    echo "=========================================="
    echo ""
    
    # Route to appropriate parser
    case "$format" in
        json)
            parse_unlock_from_json "$unlock_file"
            ;;
        text|txt)
            parse_unlock_from_text "$unlock_file"
            ;;
        *)
            echo "${ICON_ERROR} Unknown format: $format"
            echo "Supported formats: text, json"
            return 1
            ;;
    esac
}

# ============================================
# LEGACY COMPATIBILITY - Single user operations
# ============================================
# lock_user() - single user lock (backward compatible)
lock_user() {
    lock_single_user "$@"
}

# unlock_user() - single user unlock (backward compatible)
unlock_user() {
    unlock_single_user "$@"
}