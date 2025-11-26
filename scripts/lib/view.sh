#!/usr/bin/env bash
# ================================================
# View Module
# Version: 1.0.1
# ================================================

view_all_users() {
    local filter="${1:-all}"
    
    echo "=========================================="
    echo "All Users on System"
    [ "$filter" != "all" ] && echo "Filter: $filter"
    echo "=========================================="
    printf "%-15s %-6s %-15s %-20s %-8s %-12s\n" "USERNAME" "UID" "PRIMARY_GROUP" "SHELL" "STATUS" "EXPIRES"
    echo "--------------------------------------------------------------------------------"
    
    local count=0
    
    while IFS=: read -r username _ uid gid _ home shell; do
        if ! is_regular_user "$uid"; then
            [ "$filter" != "system" ] && continue
        fi
        
        local status=$(get_user_status "$username")
        local primary_group=$(id -gn "$username" 2>/dev/null)
        local expiry=$(get_account_expiry "$username")
        
        case "$filter" in
            locked) [ "$status" != "LOCKED" ] && continue ;;
            active) [ "$status" != "ACTIVE" ] && continue ;;
            sudo) ! is_user_sudo "$username" && continue ;;
            noshell) [[ ! "$shell" =~ nologin|false ]] && continue ;;
            expiring) [ "$expiry" = "Never" ] && continue ;;
        esac
        
        local short_shell=$(basename "$shell")
        printf "%-15s %-6s %-15s %-20s %-8s %-12s\n" \
            "$username" "$uid" "$primary_group" "$short_shell" "$status" "$expiry"
        
        ((count++))
    done < /etc/passwd
    
    echo "--------------------------------------------------------------------------------"
    echo "Total: $count users"
    echo ""
}

view_all_groups() {
    local filter="${1:-all}"
    
    echo "=========================================="
    echo "All Groups on System"
    [ "$filter" != "all" ] && echo "Filter: $filter"
    echo "=========================================="
    printf "%-20s %-6s %-40s %-6s\n" "GROUP_NAME" "GID" "MEMBERS" "COUNT"
    echo "--------------------------------------------------------------------------------"
    
    local count=0
    
    while IFS=: read -r groupname _ gid members; do
        local min_gid="${MIN_GROUP_GID:-1000}"
        if [ "$gid" -lt "$min_gid" ]; then
            [ "$filter" != "system" ] && [ "$filter" != "all" ] && continue
        fi
        
        local member_list="${members:-none}"
        local member_count=0
        
        if [ "$members" != "" ]; then
            member_count=$(echo "$members" | tr ',' '\n' | wc -l)
        fi
        
        case "$filter" in
            empty) [ "$member_count" -gt 0 ] && continue ;;
            user) [ "$gid" -lt "$min_gid" ] && continue ;;
            system) [ "$gid" -ge "$min_gid" ] && continue ;;
            single) [ "$member_count" -ne 1 ] && continue ;;
        esac
        
        if [ ${#member_list} -gt 40 ]; then
            member_list="${member_list:0:37}..."
        fi
        
        printf "%-20s %-6s %-40s %-6s\n" "$groupname" "$gid" "$member_list" "$member_count"
        
        ((count++))
    done < /etc/group
    
    echo "--------------------------------------------------------------------------------"
    echo "Total: $count groups"
    echo ""
}

view_user_details() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    echo "=========================================="
    echo "User Details: $username"
    echo "=========================================="
    echo ""
    
    local uid=$(id -u "$username")
    local gid=$(id -g "$username")
    local primary_group=$(id -gn "$username")
    local home=$(eval echo ~"$username")
    local shell=$(getent passwd "$username" | cut -d: -f7)
    local gecos=$(getent passwd "$username" | cut -d: -f5)
    
    echo "BASIC INFORMATION:"
    echo "  Username:         $username"
    echo "  UID:              $uid"
    echo "  Primary Group:    $primary_group ($gid)"
    echo "  Home Directory:   $home"
    echo "  Shell:            $shell"
    [ -n "$gecos" ] && echo "  Comment:          $gecos"
    echo ""
    
    local status=$(get_user_status "$username")
    echo "ACCOUNT STATUS:"
    echo "  Status:           $status"
    echo ""
    
    local all_groups=$(groups "$username" | cut -d: -f2-)
    echo "GROUPS:"
    echo "  Primary:          $primary_group ($gid)"
    echo "  All Groups:      $all_groups"
    echo ""
    
    local last_login=$(get_last_login "$username")
    echo "LOGIN INFORMATION:"
    echo "  Last Login:       $last_login"
    echo ""
    
    local acc_expires=$(get_account_expiry "$username")
    echo "ACCOUNT EXPIRATION:"
    echo "  Account Expires:  $acc_expires"
    echo ""
    
    local home_size=$(get_home_size "$username")
    local proc_count=$(($(count_user_processes "$username") - 1))
    [ "$proc_count" -lt 0 ] && proc_count=0
    local cron_count=$(count_user_cron_jobs "$username")
    
    echo "RESOURCE USAGE:"
    echo "  Home Directory:   $home_size"
    echo "  Active Processes: $proc_count"
    echo "  Cron Jobs:        $cron_count"
    echo ""
    
    if is_user_sudo "$username"; then
        echo "SUDO ACCESS:"
        echo "  Has Sudo:         YES ${ICON_WARNING}"
        echo ""
    fi
    
    echo "=========================================="
}

view_group_details() {
    local groupname="$1"
    
    if ! getent group "$groupname" >/dev/null 2>&1; then
        echo "${ICON_ERROR} Group '$groupname' does not exist"
        return 1
    fi
    
    echo "=========================================="
    echo "Group Details: $groupname"
    echo "=========================================="
    echo ""
    
    local gid=$(get_group_gid "$groupname")
    local members=$(get_group_members "$groupname")
    local member_count=0
    
    if [ -n "$members" ]; then
        member_count=$(echo "$members" | tr ',' '\n' | wc -l)
    fi
    
    echo "BASIC INFORMATION:"
    echo "  Group Name:       $groupname"
    echo "  GID:              $gid"
    
    if is_system_group "$groupname"; then
        echo "  Type:             System group"
    else
        echo "  Type:             User group"
    fi
    echo ""
    
    echo "MEMBERS: $member_count"
    if [ -n "$members" ]; then
        echo "$members" | tr ',' '\n' | while read member; do
            local uid=$(id -u "$member" 2>/dev/null)
            local primary=$(id -gn "$member" 2>/dev/null)
            local status=$(get_user_status "$member")
            echo "  $member (UID: $uid, primary: $primary, $status)"
        done
    else
        echo "  (no members)"
    fi
    echo ""
    
    local primary_users=$(find_users_with_primary_group "$groupname")
    local primary_count=0
    if [ -n "$primary_users" ]; then
        primary_count=$(echo "$primary_users" | wc -l)
    fi
    
    echo "PRIMARY GROUP FOR: $primary_count users"
    if [ -n "$primary_users" ]; then
        echo "$primary_users" | while read user; do
            echo "  $user"
        done
    else
        echo "  (not used as primary group)"
    fi
    echo ""
    
    echo "=========================================="
}

view_user_groups() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    echo "=========================================="
    echo "Groups for User: $username"
    echo "=========================================="
    echo ""
    
    local primary_group=$(id -gn "$username")
    local primary_gid=$(id -g "$username")
    local all_groups=$(groups "$username" | cut -d: -f2- | xargs)
    
    echo "PRIMARY GROUP:"
    echo "  $primary_group ($primary_gid)"
    echo ""
    
    local secondary=""
    for grp in $all_groups; do
        if [ "$grp" != "$primary_group" ]; then
            secondary="$secondary $grp"
        fi
    done
    
    secondary=$(echo "$secondary" | xargs)
    local sec_count=0
    [ -n "$secondary" ] && sec_count=$(echo "$secondary" | wc -w)
    
    echo "SECONDARY GROUPS: $sec_count"
    if [ -n "$secondary" ]; then
        for grp in $secondary; do
            local gid=$(getent group "$grp" | cut -d: -f3)
            echo "  $grp ($gid)"
        done
    else
        echo "  (none)"
    fi
    echo ""
    
    local total=$((1 + sec_count))
    echo "TOTAL: $total groups"
    echo ""
    
    if is_user_sudo "$username"; then
        echo "${ICON_WARNING} User has sudo/admin privileges"
        echo ""
    fi
    
    echo "=========================================="
}

view_system_summary() {
    echo "=========================================="
    echo "User Management System Summary"
    echo "=========================================="
    echo ""
    
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
    
    echo "USERS:"
    echo "  Total Users:      $total_users"
    echo "  Active:           $active_users"
    echo "  Locked:           $locked_users"
    echo ""
    
    local min_gid="${MIN_GROUP_GID:-1000}"
    local total_groups=$(awk -F: -v min="$min_gid" '$3 >= min' /etc/group | wc -l)
    local empty_groups=0
    
    while IFS=: read -r _ _ gid members; do
        [ "$gid" -lt "$min_gid" ] && continue
        [ -z "$members" ] && ((empty_groups++))
    done < /etc/group
    
    echo "GROUPS:"
    echo "  Total Groups:     $total_groups"
    echo "  Empty Groups:     $empty_groups"
    echo ""
    
    local sudo_count=0
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        if is_user_sudo "$username"; then
            ((sudo_count++))
        fi
    done < /etc/passwd
    
    echo "SUDO ACCESS:"
    echo "  Users with Sudo:  $sudo_count"
    echo ""
    
    local bash_count=$(awk -F: -v min="$min_uid" '$7 == "/bin/bash" && $3 >= min' /etc/passwd | wc -l)
    local nologin_count=$(awk -F: -v min="$min_uid" '$7 ~ /nologin|false/ && $3 >= min' /etc/passwd | wc -l)
    
    echo "SHELL DISTRIBUTION:"
    echo "  /bin/bash:        $bash_count users"
    echo "  /sbin/nologin:    $nologin_count users"
    echo ""
    
    echo "=========================================="
}

view_recent_logins() {
    local hours="${1:-24}"
    local days="${2:-}"
    local specific_user="${3:-}"
    
    echo "=========================================="
    if [ -n "$specific_user" ]; then
        echo "Recent Logins: $specific_user"
    else
        echo "Recent Logins"
    fi
    
    if [ -n "$days" ]; then
        echo "Period: Last $days days"
        hours=$((days * 24))
    else
        echo "Period: Last $hours hours"
    fi
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    printf "%-15s %-20s %-20s %-20s\n" "USERNAME" "TIME" "FROM" "DURATION"
    echo "------------------------------------------------------------------------"
    
    local cutoff_timestamp=$(date -d "$hours hours ago" +%s)
    local found=0
    
    while read -r line; do
        [[ "$line" =~ ^reboot ]] && continue
        [[ "$line" =~ ^wtmp ]] && continue
        
        local user=$(echo "$line" | awk '{print $1}')
        local tty=$(echo "$line" | awk '{print $2}')
        local from=$(echo "$line" | awk '{print $3}')
        local login_date=$(echo "$line" | awk '{print $4, $5, $7, $6}')
        local duration=$(echo "$line" | grep -oP '\(.*?\)' | tr -d '()')
        
        if [ -n "$specific_user" ] && [ "$user" != "$specific_user" ]; then
            continue
        fi
        
        local login_timestamp=$(date -d "$login_date" +%s 2>/dev/null)
        
        if [ -n "$login_timestamp" ] && [ "$login_timestamp" -ge "$cutoff_timestamp" ]; then
            [ "$from" = "-" ] && from="local"
            [ -z "$from" ] && from="local"
            
            local duration_display="$duration"
            if [[ "$duration" =~ still ]]; then
                local current_timestamp=$(date +%s)
                local session_seconds=$((current_timestamp - login_timestamp))
                local session_hours=$((session_seconds / 3600))
                local session_minutes=$(((session_seconds % 3600) / 60))
                duration_display="Active (${session_hours}h ${session_minutes}m)"
            elif [ -z "$duration" ]; then
                duration_display="Unknown"
            else
                duration_display="Logged out ($duration)"
            fi
            
            local login_display=$(date -d "$login_date" '+%Y-%m-%d %H:%M' 2>/dev/null)
            
            printf "%-15s %-20s %-20s %-20s\n" "$user" "$login_display" "$from" "$duration_display"
            ((found++))
        fi
    done < <(last -F -w 2>/dev/null)
    
    echo "------------------------------------------------------------------------"
    if [ "$found" -eq 0 ]; then
        echo "No logins found in the specified period"
    else
        echo "Total logins: $found"
    fi
    echo ""
    
    log_action "view_recent_logins" "${specific_user:-all}" "SUCCESS" "hours=$hours, found=$found"
}