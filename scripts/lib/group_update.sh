#!/usr/bin/env bash
# ================================================
# Group Update Module
# Version: 1.0.1
# ================================================

update_group_add_members() {
    local groupname="$1"
    local members="$2"
    
    if ! getent group "$groupname" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Group '$groupname' does not exist"
        return 1
    fi
    
    echo "Adding members to group: $groupname"
    echo "Members: $members"
    echo ""
    
    local success=0
    local failed=0
    
    IFS=',' read -ra MEMBER_ARRAY <<< "$members"
    for member in "${MEMBER_ARRAY[@]}"; do
        member=$(echo "$member" | xargs)
        
        if ! id "$member" &>/dev/null; then
            echo "  ${ICON_ERROR} User '$member' does not exist"
            ((failed++))
            continue
        fi
        
        if getent group "$groupname" | cut -d: -f4 | grep -qw "$member"; then
            echo "  ${ICON_WARNING} Already member: $member"
            continue
        fi
        
        if sudo usermod -aG "$groupname" "$member"; then
            echo "  ${ICON_SUCCESS} Added: $member"
            ((success++))
        else
            echo "  ${ICON_ERROR} Failed to add: $member"
            ((failed++))
        fi
    done
    
    echo ""
    echo "Summary: $success added, $failed failed"
    
    if [ $success -gt 0 ]; then
        echo ""
        echo "Current members:"
        getent group "$groupname" | cut -d: -f4
    fi
    
    log_action "update_group_add_members" "$groupname" "SUCCESS" "Added: $members"
}

update_group_remove_members() {
    local groupname="$1"
    local members="$2"
    
    if ! getent group "$groupname" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Group '$groupname' does not exist"
        return 1
    fi
    
    local gid=$(get_group_gid "$groupname")
    
    echo "Removing members from group: $groupname"
    echo "Members: $members"
    echo ""
    
    local success=0
    local failed=0
    
    IFS=',' read -ra MEMBER_ARRAY <<< "$members"
    for member in "${MEMBER_ARRAY[@]}"; do
        member=$(echo "$member" | xargs)
        
        if ! id "$member" &>/dev/null; then
            echo "  ${ICON_WARNING} User '$member' does not exist"
            continue
        fi
        
        local primary_gid=$(id -g "$member")
        if [ "$primary_gid" = "$gid" ]; then
            echo "  ${ICON_WARNING} Cannot remove: $member (primary group)"
            ((failed++))
            continue
        fi
        
        if ! getent group "$groupname" | cut -d: -f4 | grep -qw "$member"; then
            echo "  ${ICON_WARNING} Not a member: $member"
            continue
        fi
        
        if sudo gpasswd -d "$member" "$groupname" &>/dev/null; then
            echo "  ${ICON_SUCCESS} Removed: $member"
            ((success++))
        else
            echo "  ${ICON_ERROR} Failed to remove: $member"
            ((failed++))
        fi
    done
    
    echo ""
    echo "Summary: $success removed, $failed failed"
    
    if [ $success -gt 0 ]; then
        echo ""
        echo "Current members:"
        local current_members=$(getent group "$groupname" | cut -d: -f4)
        echo "${current_members:-(none)}"
    fi
    
    log_action "update_group_remove_members" "$groupname" "SUCCESS" "Removed: $members"
}

update_group() {
    local groupname="$1"
    local operation="$2"
    shift 2
    local value="$*"
    
    if ! getent group "$groupname" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Group '$groupname' does not exist"
        return 1
    fi
    
    case "$operation" in
        add-member|add-members)
            update_group_add_members "$groupname" "$value"
            ;;
        remove-member|remove-members)
            update_group_remove_members "$groupname" "$value"
            ;;
        *)
            echo "${ICON_ERROR} Unknown update operation: $operation"
            echo "Use: add-member, add-members, remove-member, remove-members"
            return 1
            ;;
    esac
}