#!/usr/bin/env bash
# ================================================
# JSON View Module
# Version: 1.0.1
# ================================================

view_all_users_json() {
    local filter="${1:-all}"
    
    echo "["
    local first=true
    
    while IFS=: read -r username _ uid gid _ home shell; do
        is_regular_user "$uid" || continue
        
        local status="active"
        passwd -S "$username" 2>/dev/null | grep -q " L " && status="locked"
        
        local primary_group=$(id -gn "$username" 2>/dev/null)
        local groups_list=$(groups "$username" 2>/dev/null | cut -d: -f2- | xargs)
        local groups_array=$(echo "$groups_list" | tr ' ' '\n' | while read g; do echo "\"$g\""; done | paste -sd,)
        
        local has_sudo="false"
        is_user_sudo "$username" && has_sudo="true"
        
        local expiry=$(get_account_expiry "$username")
        [ "$expiry" = "Never" ] && expiry="null"
        
        case "$filter" in
            locked) [ "$status" != "locked" ] && continue ;;
            active) [ "$status" != "active" ] && continue ;;
            sudo) [ "$has_sudo" != "true" ] && continue ;;
            noshell) [[ ! "$shell" =~ nologin|false ]] && continue ;;
            expiring) [ "$expiry" = "null" ] && continue ;;
        esac
        
        [ "$first" = false ] && echo ","
        first=false
        
        cat << EOF
  {
    "username": "$username",
    "uid": $uid,
    "gid": $gid,
    "primary_group": "$primary_group",
    "groups": [$groups_array],
    "home": "$home",
    "shell": "$shell",
    "status": "$status",
    "sudo": $has_sudo,
    "expires": $([ "$expiry" = "null" ] && echo "null" || echo "\"$expiry\"")
  }
EOF
    done < /etc/passwd
    
    echo ""
    echo "]"
}

view_all_groups_json() {
    local filter="${1:-all}"
    
    echo "["
    local first=true
    
    local min_gid="${MIN_GROUP_GID:-1000}"
    while IFS=: read -r groupname _ gid members; do
        [ "$gid" -lt "$min_gid" ] && continue
        
        local member_count=0
        local members_array="[]"
        
        if [ -n "$members" ]; then
            member_count=$(echo "$members" | tr ',' '\n' | wc -l)
            members_array="[$(echo "$members" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]"
        fi
        
        local type="user"
        is_system_group "$groupname" && type="system"
        
        case "$filter" in
            empty) [ "$member_count" -gt 0 ] && continue ;;
            user) [ "$gid" -lt "$min_gid" ] && continue ;;
            system) [ "$gid" -ge "$min_gid" ] && continue ;;
            single) [ "$member_count" -ne 1 ] && continue ;;
        esac
        
        [ "$first" = false ] && echo ","
        first=false
        
        cat << EOF
  {
    "groupname": "$groupname",
    "gid": $gid,
    "members": $members_array,
    "member_count": $member_count,
    "type": "$type"
  }
EOF
    done < /etc/group
    
    echo ""
    echo "]"
}

view_user_details_json() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        echo "{\"error\": \"User not found\", \"username\": \"$username\"}"
        return 1
    fi
    
    local uid=$(id -u "$username")
    local gid=$(id -g "$username")
    local primary_group=$(id -gn "$username")
    local home=$(eval echo ~"$username")
    local shell=$(getent passwd "$username" | cut -d: -f7)
    local gecos=$(getent passwd "$username" | cut -d: -f5)
    
    local status="active"
    passwd -S "$username" 2>/dev/null | grep -q " L " && status="locked"
    
    local groups_list=$(groups "$username" 2>/dev/null | cut -d: -f2- | xargs)
    local groups_array=$(echo "$groups_list" | tr ' ' '\n' | while read g; do echo "\"$g\""; done | paste -sd,)
    
    local has_sudo="false"
    is_user_sudo "$username" && has_sudo="true"
    
    local last_login=$(get_last_login "$username")
    [ "$last_login" = "Never" ] && last_login="null"
    
    local currently_logged_in=$(who | grep "^$username " | wc -l)
    
    local acc_expires=$(get_account_expiry "$username")
    [ "$acc_expires" = "Never" ] && acc_expires="null"
    
    local home_size="0"
    [ -d "$home" ] && home_size=$(du -sb "$home" 2>/dev/null | cut -f1)
    
    local file_count=0
    [ -d "$home" ] && file_count=$(find "$home" -type f 2>/dev/null | wc -l)
    
    local proc_count=$(($(count_user_processes "$username") - 1))
    [ "$proc_count" -lt 0 ] && proc_count=0
    
    local cron_count=$(count_user_cron_jobs "$username")
    
    cat << EOF
{
  "username": "$username",
  "uid": $uid,
  "gid": $gid,
  "primary_group": "$primary_group",
  "groups": [$groups_array],
  "home": "$home",
  "shell": "$shell",
  "comment": "$(json_escape "$gecos")",
  "status": "$status",
  "sudo": $has_sudo,
  "last_login": $([ "$last_login" = "null" ] && echo "null" || echo "\"$(json_escape "$last_login")\""),
  "currently_logged_in": $currently_logged_in,
  "account_expires": $([ "$acc_expires" = "null" ] && echo "null" || echo "\"$acc_expires\""),
  "home_size_bytes": $home_size,
  "file_count": $file_count,
  "active_processes": $proc_count,
  "cron_jobs": $cron_count
}
EOF
}

view_group_details_json() {
    local groupname="$1"
    
    if ! getent group "$groupname" >/dev/null 2>&1; then
        echo "{\"error\": \"Group not found\", \"groupname\": \"$groupname\"}"
        return 1
    fi
    
    local gid=$(get_group_gid "$groupname")
    local members=$(get_group_members "$groupname")
    
    local member_count=0
    local members_array="[]"
    
    if [ -n "$members" ]; then
        member_count=$(echo "$members" | tr ',' '\n' | wc -l)
        members_array="[$(echo "$members" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/')]"
    fi
    
    local type="user"
    is_system_group "$groupname" && type="system"
    
    local primary_users=$(find_users_with_primary_group "$groupname")
    local primary_array="[]"
    if [ -n "$primary_users" ]; then
        primary_array="[$(echo "$primary_users" | sed 's/$/"/g' | sed 's/^/"/' | paste -sd,)]"
    fi
    
    cat << EOF
{
  "groupname": "$groupname",
  "gid": $gid,
  "members": $members_array,
  "member_count": $member_count,
  "primary_for": $primary_array,
  "type": "$type"
}
EOF
}

view_user_groups_json() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        echo "{\"error\": \"User not found\", \"username\": \"$username\"}"
        return 1
    fi
    
    local primary_group=$(id -gn "$username")
    local primary_gid=$(id -g "$username")
    local all_groups=$(groups "$username" | cut -d: -f2- | xargs)
    
    local secondary=""
    for grp in $all_groups; do
        if [ "$grp" != "$primary_group" ]; then
            secondary="$secondary $grp"
        fi
    done
    secondary=$(echo "$secondary" | xargs)
    
    local secondary_array="[]"
    if [ -n "$secondary" ]; then
        secondary_array="[$(echo "$secondary" | tr ' ' '\n' | sed 's/$/"/g' | sed 's/^/"/' | paste -sd,)]"
    fi
    
    local has_sudo="false"
    is_user_sudo "$username" && has_sudo="true"
    
    cat << EOF
{
  "username": "$username",
  "primary_group": {
    "name": "$primary_group",
    "gid": $primary_gid
  },
  "secondary_groups": $secondary_array,
  "total_groups": $(echo "$all_groups" | wc -w),
  "has_sudo": $has_sudo
}
EOF
}

view_system_summary_json() {
    local min_uid="${MIN_USER_UID:-1000}"
    local max_uid="${MAX_USER_UID:-60000}"
    local total_users=$(awk -F: -v min="$min_uid" -v max="$max_uid" '$3 >= min && $3 <= max' /etc/passwd | wc -l)
    local active_users=0
    local locked_users=0
    
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        local status=$(get_user_status "$username")
        [ "$status" = "ACTIVE" ] && ((active_users++))
        [ "$status" = "LOCKED" ] && ((locked_users++))
    done < /etc/passwd
    
    local min_gid="${MIN_GROUP_GID:-1000}"
    local total_groups=$(awk -F: -v min="$min_gid" '$3 >= min' /etc/group | wc -l)
    local empty_groups=0
    
    while IFS=: read -r _ _ gid members; do
        [ "$gid" -lt "$min_gid" ] && continue
        [ -z "$members" ] && ((empty_groups++))
    done < /etc/group
    
    local sudo_users=0
    local sudo_list=""
    
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        if is_user_sudo "$username"; then
            ((sudo_users++))
            [ -n "$sudo_list" ] && sudo_list+=", "
            sudo_list+="\"$username\""
        fi
    done < /etc/passwd
    
    local bash_count=$(awk -F: -v min="$min_uid" '$7 == "/bin/bash" && $3 >= min' /etc/passwd | wc -l)
    local nologin_count=$(awk -F: -v min="$min_uid" '$7 ~ /nologin|false/ && $3 >= min' /etc/passwd | wc -l)
    
    cat << EOF
{
  "generated": "$(date '+%Y-%m-%d %H:%M:%S')",
  "hostname": "$(hostname)",
  "users": {
    "total": $total_users,
    "active": $active_users,
    "locked": $locked_users
  },
  "groups": {
    "total": $total_groups,
    "empty": $empty_groups
  },
  "sudo_users": {
    "count": $sudo_users,
    "users": [$sudo_list]
  },
  "shells": {
    "bash": $bash_count,
    "nologin": $nologin_count
  }
}
EOF
}

view_recent_logins_json() {
    local hours="${1:-24}"
    local days="${2:-}"
    local filter_user="${3:-}"
    
    if [ -n "$days" ]; then
        hours=$((days * 24))
    fi
    
    echo "["
    local first=true
    local cutoff_timestamp=$(date -d "$hours hours ago" +%s)
    
    while read -r line; do
        [[ "$line" =~ ^reboot ]] && continue
        [[ "$line" =~ ^wtmp ]] && continue
        
        local user=$(echo "$line" | awk '{print $1}')
        local tty=$(echo "$line" | awk '{print $2}')
        local from=$(echo "$line" | awk '{print $3}')
        local login_date=$(echo "$line" | awk '{print $4, $5, $7, $6}')
        local duration=$(echo "$line" | grep -oP '\(.*?\)' | tr -d '()')
        
        if [ -n "$filter_user" ] && [ "$user" != "$filter_user" ]; then
            continue
        fi
        
        local login_timestamp=$(date -d "$login_date" +%s 2>/dev/null)
        
        if [ -n "$login_timestamp" ] && [ "$login_timestamp" -ge "$cutoff_timestamp" ]; then
            [ "$from" = "-" ] && from="local"
            [ -z "$from" ] && from="local"
            
            local session_status="logged_out"
            local duration_seconds=0
            
            if [[ "$duration" =~ still ]]; then
                session_status="active"
                local current_timestamp=$(date +%s)
                duration_seconds=$((current_timestamp - login_timestamp))
            elif [[ "$duration" =~ ([0-9]+):([0-9]+) ]]; then
                local dur_hours="${BASH_REMATCH[1]}"
                local dur_mins="${BASH_REMATCH[2]}"
                duration_seconds=$(((dur_hours * 3600) + (dur_mins * 60)))
            fi
            
            [ "$first" = false ] && echo ","
            first=false
            
            cat << EOF
  {
    "username": "$user",
    "tty": "$tty",
    "from": "$from",
    "login_time": "$login_date",
    "status": "$session_status",
    "duration_seconds": $duration_seconds
  }
EOF
        fi
    done < <(last -F -w 2>/dev/null)
    
    echo ""
    echo "]"
}