#!/usr/bin/env bash
# ================================================
# User Lock Module - REFACTORED
# Version: 2.1.0
# ================================================

# ============================================
# CORE FUNCTION - Single user lock logic
# ============================================
lock_single_user() {
    local username="$1"
    local reason="${2:-No reason provided}"

    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        log_action "lock_user" "$username" "FAILED" "User not found"
        return 1
    fi

    if passwd -S "$username" 2>/dev/null | grep -q " LK "; then
        echo "${ICON_WARNING} User '$username' is already locked"
        log_action "lock_user" "$username" "SKIPPED" "Already locked"
        return 1
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "${ICON_SEARCH} [DRY-RUN] Would lock user: $username"
        [ "$reason" != "No reason provided" ] && echo "   - Reason: $reason"
        return 0
    fi

    echo "${ICON_LOCK} Locking user: $username"
    echo "   Reason: $reason"

    if sudo passwd -l "$username" &>/dev/null; then
        echo "   ${ICON_SUCCESS} User locked successfully"
        log_action "lock_user" "$username" "SUCCESS" "Reason: $reason"
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
unlock_single_user() {
    local username="$1"

    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        log_action "unlock_user" "$username" "FAILED" "User not found"
        return 1
    fi

    if ! passwd -S "$username" 2>/dev/null | grep -q " LK "; then
        echo "${ICON_WARNING} User '$username' is not locked"
        log_action "unlock_user" "$username" "SKIPPED" "Not locked"
        return 1
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "${ICON_SEARCH} [DRY-RUN] Would unlock user: $username"
        return 0
    fi

    echo "${ICON_UNLOCK} Unlocking user: $username"

    if sudo passwd -u "$username" &>/dev/null; then
        echo "   ${ICON_SUCCESS} User unlocked successfully"
        log_action "unlock_user" "$username" "SUCCESS" "User unlocked"
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
parse_lock_from_text() {
    local lock_file="$1"
    local global_reason="${2:-Bulk lock operation}"
    local count=0 locked=0 skipped=0 failed=0

    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        ((count++))
        local username reason
        if [[ "$line" =~ : ]]; then
            username=$(echo "$line" | cut -d':' -f1 | xargs)
            reason=$(echo "$line" | cut -d':' -f2- | xargs)
        else
            username=$(echo "$line" | xargs)
            reason="$global_reason"
        fi

        if lock_single_user "$username" "$reason"; then
            ((locked++))
        else
            # Check if the reason for failure was that it was already locked (skipped)
            if passwd -S "$username" 2>/dev/null | grep -q " LK "; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < "$lock_file"

    print_operation_summary "$count" "Locked" "$locked" "$skipped" "$failed"
}

# ============================================
# PARSER: Text File Format - Unlock
# ============================================
parse_unlock_from_text() {
    local unlock_file="$1"
    local count=0 unlocked=0 skipped=0 failed=0

    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        local username=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$username" ] && continue

        ((count++))
        if unlock_single_user "$username"; then
            ((unlocked++))
        else
            # Check if the reason for failure was that it was already unlocked (skipped)
            if ! passwd -S "$username" 2>/dev/null | grep -q " LK "; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < "$unlock_file"

    print_operation_summary "$count" "Unlocked" "$unlocked" "$skipped" "$failed"
}

# ============================================
# PARSER: JSON Format - Lock
# ============================================
parse_lock_from_json() {
    local json_file="$1"
    local count=0 locked=0 skipped=0 failed=0
    local start_time=$(date +%s)

    # Validate JSON structure
    if ! jq -e '.locks' "$json_file" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Invalid JSON structure - missing 'locks' array"
        return 1
    fi

    while IFS= read -r lock_json; do
        ((count++))
        local username=$(echo "$lock_json" | jq -r '.username')
        local reason=$(echo "$lock_json" | jq -r '.reason // "Locked via JSON"')

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
    print_operation_summary "$count" "Locked" "$locked" "$skipped" "$failed" "$duration"
}

# ============================================
# PARSER: JSON Format - Unlock
# ============================================
parse_unlock_from_json() {
    local json_file="$1"
    local count=0 unlocked=0 skipped=0 failed=0
    local start_time=$(date +%s)

    # Validate JSON structure
    if ! jq -e '.unlocks' "$json_file" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Invalid JSON structure - missing 'unlocks' array"
        return 1
    fi

    while IFS= read -r unlock_json; do
        ((count++))
        local username=$(echo "$unlock_json" | jq -r '.username')

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
    print_operation_summary "$count" "Unlocked" "$unlocked" "$skipped" "$failed" "$duration"
}


# ============================================
# PUBLIC INTERFACE - Lock/Unlock users
# ============================================
lock_users() {
    local target="$1"
    local format="${2:-auto}"
    local reason="${3:-No reason provided}"

    print_lock_user_banner "$target" "$format" "$reason"

    if [ -f "$target" ]; then
        if [ "$format" = "auto" ]; then
            [[ "$target" =~ \.json$ ]] && format="json" || format="text"
        fi
        
        case "$format" in
            json) parse_lock_from_json "$target" ;;
            text|txt) parse_lock_from_text "$target" "$reason" ;;
            *) echo "${ICON_ERROR} Unknown format: $format"; return 1 ;;
        esac
    else
        # Single user mode
        lock_single_user "$target" "$reason"
    fi
}

unlock_users() {
    local target="$1"
    local format="${2:-auto}"

    print_unlock_user_banner "$target" "$format"

    if [ -f "$target" ]; then
        if [ "$format" = "auto" ]; then
            [[ "$target" =~ \.json$ ]] && format="json" || format="text"
        fi

        case "$format" in
            json) parse_unlock_from_json "$target" ;;
            text|txt) parse_unlock_from_text "$target" ;;
            *) echo "${ICON_ERROR} Unknown format: $format"; return 1 ;;
        esac
    else
        # Single user mode
        unlock_single_user "$target"
    fi
}