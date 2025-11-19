#!/usr/bin/env bash
# ================================================
# Group Delete Module
# Version: 1.0.1
# ================================================

delete_check_group() {
    local groupname="$1"
    
    echo "=========================================="
    echo "Pre-Deletion Check: $groupname"
    echo "=========================================="
    echo ""
    
    if ! getent group "$groupname" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Group '$groupname' does not exist"
        return 1
    fi
    
    local gid=$(get_group_gid "$groupname")
    local members=$(get_group_members "$groupname")
    
    echo "GROUP INFORMATION:"
    echo "  Name:    $groupname"
    echo "  GID:     $gid"
    
    if is_system_group "$groupname"; then
        echo "  Type:    SYSTEM GROUP ${ICON_WARNING}"
    else
        echo "  Type:    User group"
    fi
    
    if [ -n "$members" ]; then
        echo "  Members: $members"
    else
        echo "  Members: (none)"
    fi
    echo ""
    
    local warnings=0
    
    if is_system_group "$groupname"; then
        echo "SYSTEM GROUP:"
        echo "  ${ICON_WARNING} This is a system group (GID < 1000)"
        echo "     Deletion is BLOCKED for safety"
        ((warnings++))
        echo ""
    fi
    
    echo "PRIMARY GROUP CHECK:"
    local primary_users=$(find_users_with_primary_group "$groupname")
    if [ -n "$primary_users" ]; then
        echo "  ${ICON_WARNING} Used as primary group by:"
        echo "$primary_users" | while read user; do
            echo "    - $user (will be changed to own group)"
        done
        ((warnings++))
    else
        echo "  ${ICON_SUCCESS} Not used as primary group"
    fi
    echo ""
    
    echo "FILE OWNERSHIP:"
    local files=$(find_files_by_group "$groupname")
    if [ -n "$files" ]; then
        local file_count=$(echo "$files" | wc -l)
        echo "  ${ICON_WARNING} Found $file_count+ file(s) owned by this group:"
        echo "$files" | head -10 | while read file; do
            echo "    $file"
        done
        [ "$file_count" -ge 10 ] && echo "    ... (showing first 10)"
        echo ""
        echo "  Action needed: Transfer ownership to another group"
        ((warnings++))
    else
        echo "  ${ICON_SUCCESS} No files owned by this group"
    fi
    echo ""
    
    echo "ACTIVE PROCESSES:"
    local processes=$(find_processes_by_group "$groupname")
    if [ -n "$processes" ]; then
        echo "  ${ICON_WARNING} Found process(es) running as this group:"
        echo "$processes" | head -5 | while read line; do
            echo "    $line"
        done
        ((warnings++))
    else
        echo "  ${ICON_SUCCESS} No active processes"
    fi
    echo ""
    
    echo "=========================================="
    if is_system_group "$groupname"; then
        echo "${ICON_ERROR} CANNOT DELETE: System group (GID < 1000)"
    elif [ $warnings -gt 0 ]; then
        echo "${ICON_WARNING} $warnings WARNING(S) FOUND"
    else
        echo "${ICON_SUCCESS} Safe to delete (no warnings)"
    fi
    echo "=========================================="
    
    log_action "delete_check_group" "$groupname" "COMPLETE" "$warnings warnings"
}

create_group_backup() {
    local groupname="$1"
    local backup_base="$2"
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_dir="$backup_base/${groupname}_${timestamp}"
    
    echo "${ICON_BACKUP} Creating backup: $backup_dir"
    sudo mkdir -p "$backup_dir"
    
    {
        echo "Group Deletion Backup"
        echo "===================="
        echo "Group: $groupname"
        echo "GID: $(get_group_gid "$groupname")"
        echo "Members: $(get_group_members "$groupname")"
        echo "Backup Date: $(date)"
        echo "Deleted By: $USER"
    } | sudo tee "$backup_dir/metadata.txt" >/dev/null
    
    get_group_members "$groupname" | tr ',' '\n' | sudo tee "$backup_dir/members.txt" >/dev/null
    find_users_with_primary_group "$groupname" | sudo tee "$backup_dir/primary_group_users.txt" >/dev/null
    find_files_by_group "$groupname" | sudo tee "$backup_dir/files.txt" >/dev/null
    
    echo "${ICON_SUCCESS} Backup complete"
    echo "$backup_dir"
}

delete_group_interactive() {
    local groupname="$1"
    
    echo "=========================================="
    echo "Interactive Group Deletion: $groupname"
    echo "=========================================="
    echo ""
    
    if is_system_group "$groupname"; then
        echo "${ICON_ERROR} BLOCKED: Cannot delete system group (GID < 1000)"
        return 1
    fi
    
    local gid=$(get_group_gid "$groupname")
    local members=$(get_group_members "$groupname")
    local primary_users=$(find_users_with_primary_group "$groupname")
    
    if [ -n "$primary_users" ]; then
        echo "Step 1: Primary Group Users"
        echo "  Group is primary for: $(echo "$primary_users" | tr '\n' ' ')"
        read -p "  Change to user's own group? [y/n]: " response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "$primary_users" | while read user; do
                if sudo usermod -g "$user" "$user" 2>/dev/null; then
                    echo "    ${ICON_SUCCESS} Changed $user: $groupname -> $user"
                fi
            done
        else
            echo "  ${ICON_ERROR} Cannot proceed"
            return 1
        fi
        echo ""
    fi
    
    echo "Final confirmation"
    read -p "Delete group '$groupname'? [yes/no]: " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "${ICON_ERROR} Deletion cancelled"
        return 1
    fi
    
    echo ""
    echo "${ICON_DELETE} Deleting group: $groupname"
    
    if sudo groupdel "$groupname" 2>/dev/null; then
        echo "${ICON_SUCCESS} Group deleted successfully"
        log_action "delete_group_interactive" "$groupname" "SUCCESS" ""
    else
        echo "${ICON_ERROR} Failed to delete group"
        return 1
    fi
}

delete_group_auto() {
    local groupname="$1"
    
    if is_system_group "$groupname"; then
        echo "${ICON_ERROR} BLOCKED: Cannot delete system group"
        return 1
    fi
    
    local primary_users=$(find_users_with_primary_group "$groupname")
    if [ -n "$primary_users" ]; then
        echo "$primary_users" | while read user; do
            sudo usermod -g "$user" "$user" 2>/dev/null
        done
    fi
    
    if sudo groupdel "$groupname" 2>/dev/null; then
        echo "${ICON_SUCCESS} Group deleted"
        log_action "delete_group_auto" "$groupname" "SUCCESS" ""
    fi
}

delete_group_force() {
    local groupname="$1"
    
    if is_system_group "$groupname"; then
        echo "${ICON_ERROR} BLOCKED: Cannot force delete system group"
        return 1
    fi
    
    read -p "Type group name to confirm: " confirm
    if [ "$confirm" != "$groupname" ]; then
        echo "${ICON_ERROR} Confirmation failed"
        return 1
    fi
    
    local primary_users=$(find_users_with_primary_group "$groupname")
    if [ -n "$primary_users" ]; then
        echo "$primary_users" | while read user; do
            sudo usermod -g "$user" "$user" 2>/dev/null
        done
    fi
    
    if sudo groupdel "$groupname" 2>/dev/null; then
        echo "${ICON_SUCCESS} Group deleted (force)"
        log_action "delete_group_force" "$groupname" "SUCCESS" ""
    fi
}

delete_group() {
    local groupname="$1"
    
    if ! getent group "$groupname" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Group '$groupname' does not exist"
        return 1
    fi
    
    case "$DELETE_MODE" in
        check)
            delete_check_group "$groupname"
            ;;
        interactive)
            delete_group_interactive "$groupname"
            ;;
        auto)
            delete_group_auto "$groupname"
            ;;
        force)
            delete_group_force "$groupname"
            ;;
        *)
            echo "${ICON_ERROR} Invalid delete mode: $DELETE_MODE"
            return 1
            ;;
    esac
}

delete_groups() {
    local group_file="$1"
    
    if [[ ! -f "$group_file" ]]; then
        echo "${ICON_ERROR} Group file not found: $group_file"
        exit 1
    fi
    
    echo "${ICON_WARNING} Batch Group Deletion"
    
    local count=0 deleted=0 skipped=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        
        local groupname="$line"
        count=$((count + 1))
        
        if ! getent group "$groupname" >/dev/null 2>&1; then
            skipped=$((skipped + 1))
            continue
        fi
        
        if is_system_group "$groupname"; then
            echo "${ICON_ERROR} Skipped system group: $groupname"
            skipped=$((skipped + 1))
            continue
        fi
        
        local primary_users=$(find_users_with_primary_group "$groupname")
        if [ -n "$primary_users" ]; then
            echo "$primary_users" | while read user; do
                sudo usermod -g "$user" "$user" 2>/dev/null
            done
        fi
        
        if sudo groupdel "$groupname" 2>/dev/null; then
            echo "${ICON_SUCCESS} Deleted: $groupname"
            deleted=$((deleted + 1))
        else
            skipped=$((skipped + 1))
        fi
    done < "$group_file"
    
    echo "Summary: $deleted deleted, $skipped skipped"
}