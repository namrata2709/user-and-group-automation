#!/usr/bin/env bash
# ================================================
# JSON Input Processing Module - REFACTORED
# Version: 2.1.0
# ================================================
# This file now only contains role-based and user deletion functions.
# Group management is handled in group_add.sh and group_delete.sh
# ================================================

# ============================================
# apply_roles_from_json()
# ============================================
# Applies role-based configurations from JSON
# Args:
#   $1 - JSON file path
# Returns:
#   Summary of operations
apply_roles_from_json() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        echo "${ICON_ERROR} JSON file not found: $json_file"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "${ICON_ERROR} jq required. Install with: sudo apt install jq"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$json_file" 2>/dev/null; then
        echo "${ICON_ERROR} Invalid JSON format: $json_file"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq -e '.roles' "$json_file" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Invalid JSON structure - missing 'roles' object"
        return 1
    fi
    
    if ! jq -e '.assignments' "$json_file" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Invalid JSON structure - missing 'assignments' array"
        return 1
    fi
    
    echo "============================================"
    echo "Applying Roles from: $json_file"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    echo "============================================"
    echo ""
    
    local success_count=0
    local failed_count=0
    local start_time=$(date +%s)
    
    # Parse each assignment
    while IFS= read -r assignment; do
        local username=$(echo "$assignment" | jq -r '.username')
        local role=$(echo "$assignment" | jq -r '.role')
        
        echo "Processing: $username (role: $role)"
        
        # Get role definition
        local role_def=$(jq -c ".roles.\\\"$role\\\"" "$json_file" 2>/dev/null)
        
        if [ "$role_def" = "null" ] || [ -z "$role_def" ]; then
            echo "  ${ICON_ERROR} Role '$role' not found in JSON"
            ((failed_count++))
            echo ""
            continue
        fi
        
        # Extract role settings
        local groups=$(echo "$role_def" | jq -r '.groups[]?' 2>/dev/null | paste -sd,)
        local shell=$(echo "$role_def" | jq -r '.shell // "/bin/bash"')
        local pwd_expiry=$(echo "$role_def" | jq -r '.password_expiry_days // 90')
        local description=$(echo "$role_def" | jq -r '.description // ""')
        
        echo "  Role: $role"
        [ -n "$description" ] && echo "  Description: $description"
        echo "  Shell: $shell"
        echo "  Groups: ${groups:-(none)}"
        echo "  Password expiry: $pwd_expiry days"
        echo ""
        
        # Check if user exists
        if id "$username" &>/dev/null; then
            echo "  ${ICON_INFO} User exists, updating..."
            
            if [ "$DRY_RUN" = true ]; then
                echo "  ${ICON_SEARCH} [DRY-RUN] Would update $username with role settings"
                ((success_count++))
            else
                # Update existing user
                [ -n "$groups" ] && sudo usermod -aG "$groups" "$username" 2>/dev/null
                sudo chage -M "$pwd_expiry" "$username"
                sudo usermod -s "$shell" "$username" 2>/dev/null
                
                echo "  ${ICON_SUCCESS} User updated with role settings"
                log_action "apply_role" "$username" "SUCCESS" "Role: $role, Groups: $groups"
                ((success_count++))
            fi
        else
            echo "  ${ICON_INFO} User doesn't exist, creating..."
            
            # UPDATED: Use core function from user_add.sh
            if add_single_user "$username" "$description" "0" "$shell" "no" "random" "$pwd_expiry" "$groups"; then
                ((success_count++))
            else
                ((failed_count++))
            fi
        fi
        
        echo ""
    done < <(jq -c '.assignments[]' "$json_file" 2>/dev/null)
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_operation_summary "$((success_count + failed_count))" "Applied" "$success_count" "0" "$failed_count" "$duration"
    
    return 0
}

# ============================================
# delete_users_from_json()
# ============================================
# Deletes users from a JSON file
# Args:
#   $1 - JSON file path
# Returns:
#   Summary of operations
delete_users_from_json() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        echo "${ICON_ERROR} JSON file not found: $json_file"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "${ICON_ERROR} jq required. Install with: sudo apt install jq"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$json_file" 2>/dev/null; then
        echo "${ICON_ERROR} Invalid JSON format: $json_file"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq -e '.deletions' "$json_file" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Invalid JSON structure - missing 'deletions' array"
        return 1
    fi
    
    echo "============================================"
    echo "Deleting Users from: $json_file"
    [ "$DRY_RUN" = true ] && echo "${ICON_SEARCH} DRY-RUN MODE"
    echo "============================================"
    echo ""
    
    local success_count=0
    local failed_count=0
    local start_time=$(date +%s)
    
    # Get backup directory from options
    local backup_dir=$(jq -r '.options.backup_dir // "/var/backups/users"' "$json_file")
    
    # Parse each deletion
    while IFS= read -r deletion; do
        local username=$(echo "$deletion" | jq -r '.username')
        local backup=$(echo "$deletion" | jq -r '.backup // false')
        local delete_home=$(echo "$deletion" | jq -r '.delete_home // true')
        local reason=$(echo "$deletion" | jq -r '.reason // ""')
        
        echo "Processing: $username"
        [ -n "$reason" ] && echo "  Reason: $reason"
        
        if ! id "$username" &>/dev/null; then
            echo "  ${ICON_WARNING} User does not exist"
            ((failed_count++))
            echo ""
            continue
        fi
        
        if [ "$DRY_RUN" = true ]; then
            echo "  ${ICON_SEARCH} [DRY-RUN] Would delete user with backup=$backup, delete_home=$delete_home"
            ((success_count++))
            echo ""
            continue
        fi
        
        local uid=$(id -u "$username")
        local backup_path="null"
        
        # Create backup if requested
        if [ "$backup" = "true" ]; then
            local timestamp=$(date '+%Y%m%d_%H%M%S')
            backup_path="$backup_dir/${username}_${timestamp}"
            
            echo "  ${ICON_BACKUP} Creating backup: $backup_path"
            sudo mkdir -p "$backup_path"
            
            local home=$(eval echo ~"$username")
            if [ -d "$home" ]; then
                sudo tar -czf "$backup_path/home.tar.gz" -C "$(dirname "$home")" "$(basename "$home")" 2>/dev/null
                echo "  ${ICON_SUCCESS} Home directory backed up"
            fi
            
            # Save metadata
            {
                echo "User: $username"
                echo "UID: $uid"
                echo "Deleted: $(date)"
                echo "Reason: $reason"
            } | sudo tee "$backup_path/metadata.txt" >/dev/null
        fi
        
        # Delete user
        local delete_cmd="sudo userdel"
        [ "$delete_home" = "true" ] && delete_cmd="$delete_cmd -r"
        
        if $delete_cmd "$username" 2>/dev/null; then
            echo "  ${ICON_SUCCESS} User deleted"
            [ "$backup" = "true" ] && echo "  ${ICON_BACKUP} Backup: $backup_path"
            log_action "delete_user_json" "$username" "SUCCESS" "Backup: $backup_path, Reason: $reason"
            ((success_count++))
        else
            echo "  ${ICON_ERROR} Failed to delete user"
            ((failed_count++))
        fi
        
        echo ""
    done < <(jq -c '.deletions[]' "$json_file" 2>/dev/null)
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_operation_summary "$((success_count + failed_count))" "Deleted" "$success_count" "0" "$failed_count" "$duration"
    
    return 0
}