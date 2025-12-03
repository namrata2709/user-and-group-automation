add_group() {
    local groupname="$1"
    
    # Validate group name format
    if ! validate_groupname "$groupname"; then
        echo "ERROR: Invalid group name format: $groupname"
        echo "Group names must:"
        echo "  - Start with lowercase letter or underscore"
        echo "  - Contain only lowercase, digits, hyphens, underscores"
        echo "  - Not end with hyphen"
        echo "  - Be 1-32 characters long"
        log_audit "ADD_GROUP" "$groupname" "FAILED" "Invalid group name format"
        return 1
    fi
    
    # Check if group exists
    if [ "$(group_exists "$groupname")" = "yes" ]; then
        echo "INFO: Group '$groupname' already exists"
        return 0
    fi
    
    # Create group
    if groupadd "$groupname" >/dev/null 2>&1; then
        echo "INFO: Group '$groupname' created successfully"
        log_activity "Group created: $groupname"
        log_audit "ADD_GROUP" "$groupname" "SUCCESS" "Group created"
        return 0
    else
        echo "ERROR: Failed to create group '$groupname'"
        log_audit "ADD_GROUP" "$groupname" "FAILED" "groupadd command failed"
        return 1
    fi
}