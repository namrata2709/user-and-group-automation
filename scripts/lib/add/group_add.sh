#!/bin/bash

# ================================================
# Group Add Function
# File: lib/add/group_add.sh
# ================================================

# ================================================
# Add a new group
# ================================================
# Arguments:
#   $1 - Group name
# Returns:
#   0 on success, 1 on failure
# ================================================
add_group() {
    local groupname="$1"
    
    # Validate group name (basic validation for now)
    if [ -z "$groupname" ]; then
        echo "ERROR: Group name cannot be empty"
        return 1
    fi
    
    # Check if group exists
    if [ "$(group_exists "$groupname")" = "yes" ]; then
        echo "INFO: Group '$groupname' already exists"
        return 0  # Not an error, group exists
    fi
    
    # Create group
    if groupadd "$groupname"; then
        echo "INFO: Group '$groupname' created successfully"
        return 0
    else
        echo "ERROR: Failed to create group '$groupname'"
        return 1
    fi
}