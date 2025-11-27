#!/bin/bash
add_group() {
    local groupname="$1"
    if [ -z "$groupname" ]; then
        echo "ERROR: Group name cannot be empty"
        return 1
    fi
    if [ "$(group_exists "$groupname")" = "yes" ]; then
        echo "INFO: Group '$groupname' already exists"
        return 0
    fi
    if groupadd "$groupname"; then
        echo "INFO: Group '$groupname' created successfully"
        return 0
    else
        echo "ERROR: Failed to create group '$groupname'"
        return 1
    fi
}