#!/usr/bin/env bash
# ================================================
# Search Module
# Version: 1.0.1
# ================================================

search_users() {
    local pattern="${1:-}"
    local filter_status="${2:-}"
    local filter_group="${3:-}"
    
    echo "=========================================="
    echo "Search Results: Users"
    [ -n "$pattern" ] && echo "Pattern: $pattern"
    [ -n "$filter_status" ] && echo "Status: $filter_status"
    [ -n "$filter_group" ] && echo "In Group: $filter_group"
    echo "=========================================="
    echo ""
    
    local found=0
    
    while IFS=: read -r username _ uid gid _ home shell; do
        is_regular_user "$uid" || continue
        
        if [ -n "$pattern" ]; then
            [[ ! "$username" =~ $pattern ]] && continue
        fi
        
        if [ -n "$filter_status" ]; then
            local status=$(get_user_status "$username")
            case "$filter_status" in
                locked)
                    [ "$status" != "LOCKED" ] && continue
                    ;;
                active)
                    [ "$status" != "ACTIVE" ] && continue
                    ;;
                sudo)
                    ! is_user_sudo "$username" && continue
                    ;;
            esac
        fi
        
        if [ -n "$filter_group" ]; then
            if ! groups "$username" 2>/dev/null | grep -q "\b$filter_group\b"; then
                continue
            fi
        fi
        
        local status=$(get_user_status "$username")
        local primary_group=$(id -gn "$username" 2>/dev/null)
        
        echo "Username: $username (UID: $uid)"
        echo "  Status:        $status"
        echo "  Primary Group: $primary_group"
        echo "  Shell:         $(basename "$shell")"
        echo ""
        
        ((found++))
    done < /etc/passwd
    
    echo "Found: $found user(s)"
    echo ""
}

search_groups() {
    local pattern="${1:-}"
    local filter_type="${2:-}"
    local has_member="${3:-}"
    
    echo "=========================================="
    echo "Search Results: Groups"
    [ -n "$pattern" ] && echo "Pattern: $pattern"
    [ -n "$filter_type" ] && echo "Filter: $filter_type"
    [ -n "$has_member" ] && echo "Has Member: $has_member"
    echo "=========================================="
    echo ""
    
    local found=0
    local min_gid="${MIN_GROUP_GID:-1000}"
    
    while IFS=: read -r groupname _ gid members; do
        if [ -n "$pattern" ]; then
            [[ ! "$groupname" =~ $pattern ]] && continue
        fi
        
        if [ -n "$filter_type" ]; then
            case "$filter_type" in
                empty)
                    [ -n "$members" ] && continue
                    ;;
                user)
                    [ "$gid" -lt "$min_gid" ] && continue
                    ;;
                system)
                    [ "$gid" -ge "$min_gid" ] && continue
                    ;;
            esac
        fi
        
        if [ -n "$has_member" ]; then
            if ! echo "$members" | grep -q "\b$has_member\b"; then
                continue
            fi
        fi
        
        local member_count=0
        [ -n "$members" ] && member_count=$(echo "$members" | tr ',' '\n' | wc -l)
        
        echo "Group: $groupname (GID: $gid)"
        echo "  Members: ${members:-none} ($member_count)"
        echo ""
        
        ((found++))
    done < /etc/group
    
    echo "Found: $found group(s)"
    echo ""
}