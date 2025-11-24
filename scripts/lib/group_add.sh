#!/usr/bin/env bash
# ================================================
# Group Add Module - REFACTORED
# Version: 2.1.0
# ================================================
# Single add_group logic, multiple format parsers
# ================================================

# ============================================
# CORE FUNCTION - Single group creation logic
# ============================================
add_single_group() {
    local groupname="$1"
    local members="${2:-}"
    
    if ! validate_name "$groupname" "group"; then
        log_action "add_group" "$groupname" "FAILED" "Invalid groupname"
        return 1
    fi
    
    if getent group "$groupname" >/dev/null 2>&1; then
        echo "${ICON_WARNING} Group '$groupname' already exists. Skipping..."
        log_action "add_group" "$groupname" "SKIPPED" "Already exists"
        return 1
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "${ICON_SEARCH} [DRY-RUN] Would create group: $groupname"
        [ -n "$members" ] && echo "   - Members: $members"
        return 0
    fi
    
    echo "${ICON_GROUP} Creating group: $groupname"
    if sudo groupadd "$groupname" 2>/dev/null; then
        echo "   ${ICON_SUCCESS} Group created"
        
        if [ -n "$members" ]; then
            local success=0
            local failed=0
            
            IFS=',' read -ra member_array <<< "$members"
            for member in "${member_array[@]}"; do
                member=$(echo "$member" | xargs)
                
                if ! id "$member" &>/dev/null; then
                    echo "   ${ICON_WARNING} User '$member' does not exist, skipping"
                    ((failed++))
                    continue
                fi
                
                if sudo usermod -aG "$groupname" "$member" 2>/dev/null; then
                    echo "   ${ICON_SUCCESS} Added member: $member"
                    ((success++))
                else
                    echo "   ${ICON_ERROR} Failed to add member: $member"
                    ((failed++))
                fi
            done
            
            if [ $success -gt 0 ]; then
                echo "   👥 Members added: $success"
            fi
            if [ $failed -gt 0 ]; then
                echo "   ${ICON_WARNING} Failed to add: $failed"
            fi
        fi
        
        local gid=$(getent group "$groupname" | cut -d: -f3)
        log_action "add_group" "$groupname" "SUCCESS" "GID: $gid, Members: $members"
        return 0
    else
        echo "   ${ICON_ERROR} Failed to create group: $groupname"
        log_action "add_group" "$groupname" "FAILED" "groupadd command failed"
        return 1
    fi
}

# ============================================
# PARSER: Text File Format
# ============================================
parse_groups_from_text() {
    local group_file="$1"
    
    if [[ ! -f "$group_file" ]]; then
        echo "${ICON_ERROR} Group file not found: $group_file"
        return 1
    fi
    
    local count=0 created=0 skipped=0 failed=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        local groupname="$line"
        count=$((count + 1))
        
        if add_single_group "$groupname" ""; then
            ((created++))
        else
            if getent group "$groupname" >/dev/null 2>&1; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < "$group_file"
    
    print_operation_summary "$count" "Created" "$created" "$skipped" "$failed"
    
    return 0
}

# ============================================
# PARSER: JSON Format
# ============================================
parse_groups_from_json() {
    local json_file="$1"
    
    if ! command -v jq &> /dev/null; then
        echo "${ICON_ERROR} jq not installed. Install with: sudo apt install jq"
        return 1
    fi
    
    if ! jq empty "$json_file" 2>/dev/null; then
        echo "${ICON_ERROR} Invalid JSON format: $json_file"
        return 1
    fi
    
    if ! jq -e '.groups' "$json_file" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Invalid JSON structure - missing 'groups' array"
        return 1
    fi
    
    local count=0 created=0 skipped=0 failed=0
    local start_time=$(date +%s)
    
    while IFS= read -r group_json; do
        ((count++))
        
        local groupname=$(echo "$group_json" | jq -r '.name')
        local action=$(echo "$group_json" | jq -r '.action // "create"')
        local members=$(echo "$group_json" | jq -r '.members[]?' 2>/dev/null | paste -sd, | sed 's/,$//')
        
        if [ "$action" != "create" ]; then
            echo "${ICON_WARNING} Skipping group '$groupname' - action is '$action' (not 'create')"
            ((skipped++))
            continue
        fi
        
        if add_single_group "$groupname" "$members"; then
            ((created++))
        else
            if getent group "$groupname" >/dev/null 2>&1; then
                ((skipped++))
            else
                ((failed++))
            fi
        fi
        echo ""
    done < <(jq -c '.groups[]' "$json_file" 2>/dev/null)
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_operation_summary "$count" "Created" "$created" "$skipped" "$failed" "$duration"
    
    return 0
}

# ============================================
# PUBLIC INTERFACE - Called from user.sh
# ============================================
add_groups() {
    local group_file="$1"
    local format="${2:-auto}"
    
    if [[ ! -f "$group_file" ]]; then
        echo "${ICON_ERROR} Group file not found: $group_file"
        return 1
    fi
    
    if [ "$format" = "auto" ]; then
        if [[ "$group_file" =~ \.json$ ]]; then
            format="json"
        else
            format="text"
        fi
    fi
    
    print_add_group_banner "$group_file" "$format"
    
    case "$format" in
        json)
            parse_groups_from_json "$group_file"
            ;;
        text|txt)
            parse_groups_from_text "$group_file"
            ;;
        *)
            echo "${ICON_ERROR} Unknown format: $format"
            echo "Supported formats: text, json"
            return 1
            ;;
    esac
}

# ============================================
# LEGACY COMPATIBILITY
# ============================================
# Keep old function names for backward compatibility
add_groups_from_json() {
    parse_groups_from_json "$1"
}