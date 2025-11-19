#!/usr/bin/env bash
# ================================================
# JSON Search Module
# Version: 1.0.1
# ================================================

search_users_json() {
    local pattern="${1:-}"
    local filter_status="${2:-}"
    local filter_group="${3:-}"
    
    echo "["
    local first=true
    
    while IFS=: read -r username _ uid gid _ home shell; do
        is_regular_user "$uid" || continue
        
        if [ -n "$pattern" ]; then
            [[ ! "$username" =~ $pattern ]] && continue
        fi
        
        if [ -n "$filter_status" ]; then
            local status=$(get_user_status "$username")
            case "$filter_status" in
                locked) [ "$status" != "LOCKED" ] && continue ;;
                active) [ "$status" != "ACTIVE" ] && continue ;;
                sudo) ! is_user_sudo "$username" && continue ;;
            esac
        fi
        
        if [ -n "$filter_group" ]; then
            if ! groups "$username" 2>/dev/null | grep -q "\b$filter_group\b"; then
                continue
            fi
        fi
        
        local status=$(get_user_status "$username")
        local primary_group=$(id -gn "$username" 2>/dev/null)
        local groups_list=$(groups "$username" 2>/dev/null | cut -d: -f2- | xargs)
        local groups_array=$(echo "$groups_list" | tr ' ' '\n' | while read g; do echo "\"$g\""; done | paste -sd,)
        
        [ "$first" = false ] && echo ","
        first=false
        
        cat << EOF
  {
    "username": "$username",
    "uid": $uid,
    "primary_group": "$primary_group",
    "groups": [$groups_array],
    "shell": "$(basename "$shell")",
    "status": "$status"
  }
EOF
    done < /etc/passwd
    
    echo ""
    echo "]"
}

search_groups_json() {
    local pattern="${1:-}"
    local filter_type="${2:-}"
    local has_member="${3:-}"
    
    echo "["
    local first=true
    
    local min_gid="${MIN_GROUP_GID:-1000}"
    while IFS=: read -r groupname _ gid members; do
        if [ -n "$pattern" ]; then
            [[ ! "$groupname" =~ $pattern ]] && continue
        fi
        
        if [ -n "$filter_type" ]; then
            case "$filter_type" in
                empty) [ -n "$members" ] && continue ;;
                user) [ "$gid" -lt "$min_gid" ] && continue ;;
                system) [ "$gid" -ge "$min_gid" ] && continue ;;
            esac
        fi
        
        if [ -n "$has_member" ]; then
            if ! echo "$members" | grep -q "\b$has_member\b"; then
                continue
            fi
        fi
        
        local member_count=0
        local members_array="[]"
        
        if [ -n "$members" ]; then
            member_count=$(echo "$members" | tr ',' '\n' | wc -l)
            members_array="[$(echo "$members" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]"
        fi
        
        [ "$first" = false ] && echo ","
        first=false
        
        cat << EOF
  {
    "groupname": "$groupname",
    "gid": $gid,
    "members": $members_array,
    "member_count": $member_count
  }
EOF
    done < /etc/group
    
    echo ""
    echo "]"
}