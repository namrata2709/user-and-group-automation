#!/usr/bin/env bash
# ================================================
# Group Add Module - REFACTORED
# Version: 2.0.0
# ================================================
# Single add_group logic, multiple format parsers
# ================================================

# ============================================
# CORE FUNCTION - Single group creation logic
# ============================================
# add_single_group()
# Creates a single group with given parameters
# Args:
#   $1 - groupname (required)
#   $2 - members (comma-separated usernames, optional)
# Returns:
#   0 on success, 1 on failure
add_single_group() {
    local groupname="$1"
    local members="${2:-}"
    
    # Validate groupname
    if ! validate_name "$groupname" "group"; then
        log_action "add_group" "$groupname" "FAILED" "Invalid groupname"
        return 1
    fi
    
    # Check if group already exists
    if getent group "$groupname" >/dev/null 2>&1; then
        echo "${ICON_WARNING} Group '$groupname' already exists. Skipping..."
        log_action "add_group" "$groupname" "SKIPPED" "Already exists"
        return 1
    fi
    
    # DRY-RUN mode
    if [ "$DRY_RUN" = true ]; then
        echo "${ICON_SEARCH} [DRY-RUN] Would create group: $groupname"
        [ -n "$members" ] && echo "   - Members: $members"
        return 0
    fi
    
    # Create group
    echo "${ICON_GROUP} Creating group: $groupname"
    if sudo groupadd "$groupname" 2>/dev/null; then
        echo "   ${ICON_SUCCESS} Group created"
        
        # Add members if specified
        if [ -n "$members" ]; then
            local success=0
            local failed=0
            
            IFS=',' read -ra member_array <<< "$members"
            for member in "${member_array[@]}"; do
                member=$(echo "$member" | xargs)
                
                # Check if user exists
                if ! id "$member" &>/dev/null; then
                    echo "   ${ICON_WARNING} User '$member' does not exist, skipping"
                    ((failed++))
                    continue
                fi
                
                # Add user to group
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
# parse_groups_from_text()
# Parses text file and calls add_single_group for each
# Format: groupname
# Args:
#   $1 - text file path
# Returns:
#   Summary counts
parse_groups_from_text() {
    local group_file="$1"
    
    if [[ ! -f "$group_file" ]]; then
        echo "${ICON_ERROR} Group file not found: $group_file"
        return 1
    fi
    
    local count=0 created=0 skipped=0 failed=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        local groupname="$line"
        count=$((count + 1))
        
        # Call core function
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
    
    echo "=========================================="
    echo "Summary:"
    echo "  Total processed: $count"
    echo "  Created: $created"
    echo "  Skipped: $skipped"
    echo "  Failed: $failed"
    echo "=========================================="
    
    return 0
}

# ============================================
# PARSER: JSON Format
# ============================================
# parse_groups_from_json()
# Parses JSON file and calls add_single_group for each
# Args:
#   $1 - JSON file path
# Returns:
#   Summary counts
parse_groups_from_json() {
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
    if ! jq -e '.groups' "$json_file" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Invalid JSON structure - missing 'groups' array"
        return 1
    fi
    
    local count=0 created=0 skipped=0 failed=0
    local start_time=$(date +%s)
    
    # Parse each group from JSON
    while IFS= read -r group_json; do
        ((count++))
        
        # Extract fields from JSON
        local groupname=$(echo "$group_json" | jq -r '.name')
        local action=$(echo "$group_json" | jq -r '.action // "create"')
        local members=$(echo "$group_json" | jq -r '.members[]?' 2>/dev/null | paste -sd,)
        
        # Only process 'create' actions in this function
        # 'delete' actions are handled by group_delete.sh
        if [ "$action" != "create" ]; then
            echo "${ICON_WARNING} Skipping group '$groupname' - action is '$action' (not 'create')"
            ((skipped++))
            continue
        fi
        
        # Call core function
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
    
    echo "=========================================="
    echo "Summary:"
    echo "  Total processed: $count"
    echo "  Created: $created"
    echo "  Skipped: $skipped"
    echo "  Failed: $failed"
    echo "  Duration: ${duration}s"
    echo "=========================================="
    
    return 0
}

# ============================================
# PUBLIC INTERFACE - Called from user.sh
# ============================================
# add_groups()
# Main entry point - detects format and routes to appropriate parser
# Args:
#   $1 - file path
#   $2 - format (optional: "text", "json", auto-detect if not provided)
# Returns:
#   0 on success, 1 on failure
add_groups() {
    local group_file="$1"
    local format="${2:-auto}"
    
    if [[ ! -f "$group_file" ]]; then
        echo "${ICON_ERROR} Group file not found: $group_file"
        return 1
    fi
    
    # Auto-detect format if not specified
    if [ "$format" = "auto" ]; then
        if [[ "$group_file" =~ \.json$ ]]; then
            format="json"
        else
            format="text"
        fi
    fi
    
    echo "=========================================="
    echo "Adding Groups from: $group_file"
    echo "Format: $format"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    echo "=========================================="
    echo ""
    
    # Route to appropriate parser
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