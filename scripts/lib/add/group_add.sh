#!/bin/bash

add_group() {
    local groupname="$1"
    local trusted="${2:-no}"
    
    # Basic checks always run
    if [ -z "$groupname" ]; then
        echo "ERROR: Group name cannot be empty"
        return 1
    fi
    
    # Validate only if NOT trusted
    if [ "$trusted" != "yes" ]; then
        # Validate group name format
        if ! validate_groupname "$groupname"; then
            echo "ERROR: Invalid group name format: $groupname"
            echo "Group names must:"
            echo "  - Start with lowercase letter or underscore"
            echo "  - Contain only lowercase, digits, hyphens, underscores"
            echo "  - Not end with hyphen"
            echo "  - Be 1-32 characters long"
            return 1
        fi
    fi
    
    # Check if group exists
    if [ "$(group_exists "$groupname")" = "yes" ]; then
        if [ "$trusted" = "yes" ]; then
            # Silent success for batch operations
            return 0
        else
            echo "INFO: Group '$groupname' already exists"
            return 0
        fi
    fi
    
    # Create group
    if groupadd "$groupname" >/dev/null 2>&1; then
        echo "INFO: Group '$groupname' created successfully"
        log_activity "Group created: $groupname"
        return 0
    else
        echo "ERROR: Failed to create group '$groupname'"
        log_audit "ADD_GROUP" "$groupname" "FAILED" "groupadd command failed"
        return 1
    fi
}