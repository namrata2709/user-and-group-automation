#!/usr/bin/env bash
# ================================================
# JSON Input Processing Module
# Version: 1.0.1
# ================================================
# Processes JSON input files for bulk operations
# ================================================

# add_users_from_json()
# Adds users from a JSON file
# Args:
#   $1 - JSON file path
# Returns:
#   JSON result summary
add_users_from_json() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        echo "{\"error\":\"JSON file not found\",\"file\":\"$json_file\"}"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "{\"error\":\"jq not installed. Install with: sudo apt install jq\"}"
        return 1
    fi
    
    if ! jq empty "$json_file" 2>/dev/null; then
        echo "{\"error\":\"Invalid JSON format\",\"file\":\"$json_file\"}"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq -e '.users' "$json_file" >/dev/null 2>&1; then
        echo "{\"error\":\"Invalid JSON structure - missing 'users' array\",\"file\":\"$json_file\"}"
        return 1
    fi
    
    local results=()
    local success_count=0
    local failed_count=0
    local start_time=$(date +%s)
    
    local users=$(jq -c '.users[]' "$json_file" 2>/dev/null)
    
    while IFS= read -r user_json; do
        local username=$(echo "$user_json" | jq -r '.username')
        local comment=$(echo "$user_json" | jq -r '.comment // ""')
        local groups=$(echo "$user_json" | jq -r '.groups[]?' | paste -sd,)
        local shell=$(echo "$user_json" | jq -r '.shell // "/bin/bash"')
        local expire_days=$(echo "$user_json" | jq -r '.expire_days // "0"')
        local password_type=$(echo "$user_json" | jq -r '.password_policy.type // "default"')
        local password_expiry=$(echo "$user_json" | jq -r '.password_policy.expiry_days // "90"')
        
        if ! validate_name "$username" "user"; then
            results+=("{\"username\":\"$username\",\"status\":\"failed\",\"reason\":\"Invalid username\"}")
            ((failed_count++))
            continue
        fi
        
        if id "$username" &>/dev/null; then
            results+=("{\"username\":\"$username\",\"status\":\"skipped\",\"reason\":\"Already exists\"}")
            continue
        fi
        
        local create_opts="-m -s $shell"
        [ -n "$comment" ] && create_opts="$create_opts -c \"$comment\""
        
        if eval sudo useradd $create_opts "$username" 2>/dev/null; then
            local uid=$(id -u "$username")
            
            if [ "$password_type" = "random" ]; then
                local password=$(generate_random_password "${PASSWORD_LENGTH:-16}")
                echo "$username:$password" | sudo chpasswd
            else
                echo "$username:$DEFAULT_PASSWORD" | sudo chpasswd
            fi
            
            sudo chage -d 0 "$username"
            sudo chage -M "$password_expiry" "$username"
            
            [ -n "$groups" ] && sudo usermod -aG "$groups" "$username" 2>/dev/null
            
            if [ "$expire_days" -gt 0 ]; then
                local expire_date=$(date -d "+${expire_days} days" +%Y-%m-%d)
                sudo chage -E "$expire_date" "$username"
            fi
            
            results+=("{\"username\":\"$username\",\"status\":\"success\",\"uid\":$uid}")
            ((success_count++))
            log_action "add_user_json" "$username" "SUCCESS" "From JSON file"
        else
            results+=("{\"username\":\"$username\",\"status\":\"failed\",\"reason\":\"Creation failed\"}")
            ((failed_count++))
        fi
    done <<< "$users"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    cat << EOF
{
  "operation": "bulk_add_users_from_json",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "source_file": "$json_file",
  "results": [
    $(IFS=,; echo "${results[*]}")
  ],
  "summary": {
    "total": $((success_count + failed_count)),
    "success": $success_count,
    "failed": $failed_count,
    "duration_seconds": $duration
  }
}
EOF
}

# apply_roles_from_json()
# Applies role-based configurations from JSON
# Args:
#   $1 - JSON file path
# Returns:
#   JSON result summary
apply_roles_from_json() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        echo "{\"error\":\"JSON file not found\"}"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "{\"error\":\"jq required\"}"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq -e '.roles' "$json_file" >/dev/null 2>&1; then
        echo "{\"error\":\"Invalid JSON structure - missing 'roles' object\"}"
        return 1
    fi
    
    if ! jq -e '.assignments' "$json_file" >/dev/null 2>&1; then
        echo "{\"error\":\"Invalid JSON structure - missing 'assignments' array\"}"
        return 1
    fi
    
    local results=()
    local success_count=0
    local failed_count=0
    
    local assignments=$(jq -c '.assignments[]' "$json_file" 2>/dev/null)
    
    while IFS= read -r assignment; do
        local username=$(echo "$assignment" | jq -r '.username')
        local role=$(echo "$assignment" | jq -r '.role')
        
        local role_def=$(jq -c ".roles.\"$role\"" "$json_file" 2>/dev/null)
        
        if [ "$role_def" = "null" ]; then
            results+=("{\"username\":\"$username\",\"role\":\"$role\",\"status\":\"failed\",\"reason\":\"Role not found\"}")
            ((failed_count++))
            continue
        fi
        
        local groups=$(echo "$role_def" | jq -r '.groups[]?' | paste -sd,)
        local shell=$(echo "$role_def" | jq -r '.shell // "/bin/bash"')
        local pwd_expiry=$(echo "$role_def" | jq -r '.password_expiry_days // 90')
        
        if ! id "$username" &>/dev/null; then
            sudo useradd -m -s "$shell" "$username" 2>/dev/null || {
                results+=("{\"username\":\"$username\",\"role\":\"$role\",\"status\":\"failed\",\"reason\":\"Creation failed\"}")
                ((failed_count++))
                continue
            }
        fi
        
        [ -n "$groups" ] && sudo usermod -aG "$groups" "$username" 2>/dev/null
        sudo chage -M "$pwd_expiry" "$username"
        
        results+=("{\"username\":\"$username\",\"role\":\"$role\",\"status\":\"success\",\"groups\":\"$groups\"}")
        ((success_count++))
        log_action "apply_role" "$username" "SUCCESS" "Role: $role"
    done <<< "$assignments"
    
    cat << EOF
{
  "operation": "apply_roles",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "source_file": "$json_file",
  "results": [
    $(IFS=,; echo "${results[*]}")
  ],
  "summary": {
    "total": $((success_count + failed_count)),
    "success": $success_count,
    "failed": $failed_count
  }
}
EOF
}

# delete_users_from_json()
# Deletes users from a JSON file
# Args:
#   $1 - JSON file path
# Returns:
#   JSON result summary
delete_users_from_json() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        echo "{\"error\":\"JSON file not found\"}"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "{\"error\":\"jq required\"}"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq -e '.deletions' "$json_file" >/dev/null 2>&1; then
        echo "{\"error\":\"Invalid JSON structure - missing 'deletions' array\"}"
        return 1
    fi
    
    local results=()
    local success_count=0
    local failed_count=0
    
    local deletions=$(jq -c '.deletions[]' "$json_file" 2>/dev/null)
    
    while IFS= read -r deletion; do
        local username=$(echo "$deletion" | jq -r '.username')
        local backup=$(echo "$deletion" | jq -r '.backup // false')
        local delete_home=$(echo "$deletion" | jq -r '.delete_home // true')
        
        if ! id "$username" &>/dev/null; then
            results+=("{\"username\":\"$username\",\"status\":\"failed\",\"reason\":\"User not found\"}")
            ((failed_count++))
            continue
        fi
        
        local uid=$(id -u "$username")
        local backup_path="null"
        
        if [ "$backup" = "true" ]; then
            local backup_dir=$(jq -r '.options.backup_dir // "/var/backups/users"' "$json_file")
            local timestamp=$(date '+%Y%m%d_%H%M%S')
            backup_path="$backup_dir/${username}_${timestamp}"
            sudo mkdir -p "$backup_path"
            
            local home=$(eval echo ~"$username")
            [ -d "$home" ] && sudo tar -czf "$backup_path/home.tar.gz" -C "$(dirname "$home")" "$(basename "$home")" 2>/dev/null
        fi
        
        local delete_cmd="sudo userdel"
        [ "$delete_home" = "true" ] && delete_cmd="$delete_cmd -r"
        
        if $delete_cmd "$username" 2>/dev/null; then
            results+=("{\"username\":\"$username\",\"status\":\"success\",\"uid\":$uid,\"backup\":\"$backup_path\"}")
            ((success_count++))
            log_action "delete_user_json" "$username" "SUCCESS" "Backup: $backup_path"
        else
            results+=("{\"username\":\"$username\",\"status\":\"failed\",\"reason\":\"Deletion failed\"}")
            ((failed_count++))
        fi
    done <<< "$deletions"
    
    cat << EOF
{
  "operation": "batch_delete_users",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "source_file": "$json_file",
  "results": [
    $(IFS=,; echo "${results[*]}")
  ],
  "summary": {
    "total": $((success_count + failed_count)),
    "success": $success_count,
    "failed": $failed_count
  }
}
EOF
}

# manage_groups_from_json()
# Manages groups from a JSON file
# Args:
#   $1 - JSON file path
# Returns:
#   JSON result summary
manage_groups_from_json() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        echo "{\"error\":\"JSON file not found\"}"
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "{\"error\":\"jq required\"}"
        return 1
    fi
    
    # Validate JSON structure
    if ! jq -e '.groups' "$json_file" >/dev/null 2>&1; then
        echo "{\"error\":\"Invalid JSON structure - missing 'groups' array\"}"
        return 1
    fi
    
    local results=()
    local success_count=0
    local failed_count=0
    
    local groups=$(jq -c '.groups[]' "$json_file" 2>/dev/null)
    
    while IFS= read -r group_data; do
        local name=$(echo "$group_data" | jq -r '.name')
        local action=$(echo "$group_data" | jq -r '.action')
        
        case "$action" in
            create)
                if getent group "$name" >/dev/null 2>&1; then
                    results+=("{\"group\":\"$name\",\"action\":\"create\",\"status\":\"skipped\",\"reason\":\"Already exists\"}")
                    continue
                fi
                
                if sudo groupadd "$name" 2>/dev/null; then
                    local gid=$(getent group "$name" | cut -d: -f3)
                    local members=$(echo "$group_data" | jq -r '.members[]?' | paste -sd,)
                    
                    if [ -n "$members" ]; then
                        IFS=',' read -ra member_array <<< "$members"
                        for member in "${member_array[@]}"; do
                            sudo usermod -aG "$name" "$member" 2>/dev/null
                        done
                    fi
                    
                    results+=("{\"group\":\"$name\",\"action\":\"create\",\"status\":\"success\",\"gid\":$gid}")
                    ((success_count++))
                    log_action "create_group_json" "$name" "SUCCESS" "Members: $members"
                else
                    results+=("{\"group\":\"$name\",\"action\":\"create\",\"status\":\"failed\"}")
                    ((failed_count++))
                fi
                ;;
                
            delete)
                if ! getent group "$name" >/dev/null 2>&1; then
                    results+=("{\"group\":\"$name\",\"action\":\"delete\",\"status\":\"failed\",\"reason\":\"Not found\"}")
                    ((failed_count++))
                    continue
                fi
                
                if sudo groupdel "$name" 2>/dev/null; then
                    results+=("{\"group\":\"$name\",\"action\":\"delete\",\"status\":\"success\"}")
                    ((success_count++))
                    log_action "delete_group_json" "$name" "SUCCESS" ""
                else
                    results+=("{\"group\":\"$name\",\"action\":\"delete\",\"status\":\"failed\"}")
                    ((failed_count++))
                fi
                ;;
        esac
    done <<< "$groups"
    
    cat << EOF
{
  "operation": "manage_groups",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "source_file": "$json_file",
  "results": [
    $(IFS=,; echo "${results[*]}")
  ],
  "summary": {
    "total": $((success_count + failed_count)),
    "success": $success_count,
    "failed": $failed_count
  }
}
EOF
}