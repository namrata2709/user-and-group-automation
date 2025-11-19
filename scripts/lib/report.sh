#!/usr/bin/env bash
# ================================================
# Audit Report Module
# Version: 1.0.1
# ================================================

report_security() {
    echo "=========================================="
    echo "Security Audit Report"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    # Users with sudo access
    echo "1. USERS WITH SUDO ACCESS:"
    local sudo_count=0
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        if is_user_sudo "$username"; then
            local status=$(get_user_status "$username")
            local last_login=$(get_last_login "$username")
            echo "  ${ICON_WARNING} $username (UID: $uid, Status: $status)"
            echo "      Last login: $last_login"
            ((sudo_count++))
        fi
    done < /etc/passwd
    [ "$sudo_count" -eq 0 ] && echo "  ${ICON_SUCCESS} None found"
    echo ""
    
    # Locked accounts
    echo "2. LOCKED ACCOUNTS:"
    local locked_count=0
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        if passwd -S "$username" 2>/dev/null | grep -q " L "; then
            local groups=$(groups "$username" 2>/dev/null | cut -d: -f2-)
            echo "  ${ICON_LOCK} $username (UID: $uid)"
            echo "      Groups: $groups"
            ((locked_count++))
        fi
    done < /etc/passwd
    [ "$locked_count" -eq 0 ] && echo "  ${ICON_SUCCESS} None found"
    echo ""
    
    # Expired passwords
    echo "3. EXPIRED PASSWORDS:"
    local expired_count=0
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        local pwd_status=$(sudo chage -l "$username" 2>/dev/null | grep "Password expires" | cut -d: -f2 | xargs)
        if [[ "$pwd_status" =~ ^[A-Z][a-z]{2}[[:space:]][A-Z][a-z]{2}[[:space:]][0-9]{1,2} ]]; then
            local expiry_date=$(date -d "$pwd_status" +%s 2>/dev/null)
            local current_date=$(date +%s)
            if [ -n "$expiry_date" ] && [ "$expiry_date" -lt "$current_date" ]; then
                echo "  ${ICON_WARNING} $username - Expired: $pwd_status"
                ((expired_count++))
            fi
        fi
    done < /etc/passwd
    [ "$expired_count" -eq 0 ] && echo "  ${ICON_SUCCESS} None found"
    echo ""
    
    # Accounts without password expiry
    echo "4. ACCOUNTS WITHOUT PASSWORD EXPIRY:"
    local no_expiry_count=0
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        local max_days=$(sudo chage -l "$username" 2>/dev/null | grep "Maximum number of days" | grep -oE '[0-9]+')
        if [ "$max_days" = "99999" ] || [ -z "$max_days" ]; then
            local status=$(get_user_status "$username")
            echo "  ${ICON_WARNING} $username (Status: $status)"
            ((no_expiry_count++))
        fi
    done < /etc/passwd
    [ "$no_expiry_count" -eq 0 ] && echo "  ${ICON_SUCCESS} All accounts have password expiry"
    echo ""
    
    # Empty groups
    echo "5. EMPTY GROUPS:"
    local empty_count=0
    local min_gid="${MIN_GROUP_GID:-1000}"
    while IFS=: read -r groupname _ gid members; do
        [ "$gid" -lt "$min_gid" ] && continue
        if [ -z "$members" ]; then
            local primary_users=$(find_users_with_primary_group "$groupname")
            if [ -z "$primary_users" ]; then
                echo "  ${ICON_WARNING} $groupname (GID: $gid) - No members, not used as primary"
                ((empty_count++))
            fi
        fi
    done < /etc/group
    [ "$empty_count" -eq 0 ] && echo "  ${ICON_SUCCESS} No empty groups"
    echo ""
    
    # Users in system groups (risky)
    echo "6. USERS IN SYSTEM GROUPS (GID < 1000):"
    local system_group_users=0
    while IFS=: read -r groupname _ gid members; do
        [ "$gid" -ge "$min_gid" ] && continue
        [ -z "$members" ] && continue
        IFS=',' read -ra member_array <<< "$members"
        for member in "${member_array[@]}"; do
            local member_uid=$(id -u "$member" 2>/dev/null)
            if [ -n "$member_uid" ] && is_regular_user "$member_uid"; then
                echo "  ${ICON_WARNING} $member in system group: $groupname"
                ((system_group_users++))
            fi
        done
    done < /etc/group
    [ "$system_group_users" -eq 0 ] && echo "  ${ICON_SUCCESS} No regular users in system groups"
    echo ""
    
    # Users without shell (service accounts)
    echo "7. USERS WITHOUT SHELL (Service Accounts):"
    local noshell_count=0
    while IFS=: read -r username _ uid _ _ _ shell; do
        is_regular_user "$uid" || continue
        if [[ "$shell" =~ nologin|false ]]; then
            local groups=$(groups "$username" 2>/dev/null | cut -d: -f2-)
            echo "  ${ICON_INFO} $username (UID: $uid, Shell: $shell)"
            echo "      Groups: $groups"
            ((noshell_count++))
        fi
    done < /etc/passwd
    [ "$noshell_count" -eq 0 ] && echo "  ${ICON_SUCCESS} All users have login shells"
    echo ""
    
    # Duplicate UIDs
    echo "8. DUPLICATE UIDs:"
    local min_uid="${MIN_USER_UID:-1000}"
    local dup_uids=$(awk -F: -v min="$min_uid" '$3 >= min {print $3}' /etc/passwd | sort | uniq -d)
    if [ -n "$dup_uids" ]; then
        echo "$dup_uids" | while read uid; do
            echo "  ${ICON_WARNING} UID $uid used by:"
            awk -F: -v uid="$uid" -v min="$min_uid" '$3 == uid && $3 >= min {print "      - " $1}' /etc/passwd
        done
    else
        echo "  ${ICON_SUCCESS} No duplicate UIDs"
    fi
    echo ""
    
    # Duplicate GIDs
    echo "9. DUPLICATE GIDs:"
    local dup_gids=$(awk -F: -v min="$min_gid" '$3 >= min {print $3}' /etc/group | sort | uniq -d)
    if [ -n "$dup_gids" ]; then
        echo "$dup_gids" | while read gid; do
            echo "  ${ICON_WARNING} GID $gid used by:"
            awk -F: -v gid="$gid" -v min="$min_gid" '$3 == gid && $3 >= min {print "      - " $1}' /etc/group
        done
    else
        echo "  ${ICON_SUCCESS} No duplicate GIDs"
    fi
    echo ""
    
    # Summary
    echo "=========================================="
    echo "SECURITY SUMMARY:"
    echo "  Sudo users:           $sudo_count"
    echo "  Locked accounts:      $locked_count"
    echo "  Expired passwords:    $expired_count"
    echo "  No password expiry:   $no_expiry_count"
    echo "  Empty groups:         $empty_count"
    echo "  System group members: $system_group_users"
    echo "  Service accounts:     $noshell_count"
    echo "=========================================="
    
    log_action "report_security" "system" "SUCCESS" "Generated security audit report"
}

report_compliance() {
    echo "=========================================="
    echo "Compliance Report"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    # Password policy compliance
    echo "1. PASSWORD POLICY COMPLIANCE:"
    local compliant=0
    local non_compliant=0
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        local max_days=$(sudo chage -l "$username" 2>/dev/null | grep "Maximum number of days" | grep -oE '[0-9]+')
        if [ "$max_days" = "99999" ] || [ -z "$max_days" ]; then
            echo "  ${ICON_ERROR} $username - No password expiry set"
            ((non_compliant++))
        elif [ "$max_days" -gt 90 ]; then
            echo "  ${ICON_WARNING} $username - Password expiry: $max_days days (recommended: ≤90)"
            ((non_compliant++))
        else
            ((compliant++))
        fi
    done < /etc/passwd
    echo "  Compliant: $compliant | Non-compliant: $non_compliant"
    echo ""
    
    # Account expiration compliance
    echo "2. ACCOUNT EXPIRATION COMPLIANCE:"
    local expired=0
    local expiring_soon=0
    local no_expiry=0
    local current_timestamp=$(date +%s)
    local thirty_days=$((30 * 86400))
    
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        local expiry=$(sudo chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
        if [ "$expiry" = "never" ]; then
            ((no_expiry++))
        elif [[ "$expiry" =~ ^[A-Z][a-z]{2}[[:space:]][A-Z][a-z]{2}[[:space:]][0-9]{1,2} ]]; then
            local expiry_timestamp=$(date -d "$expiry" +%s 2>/dev/null)
            if [ -n "$expiry_timestamp" ]; then
                if [ "$expiry_timestamp" -lt "$current_timestamp" ]; then
                    echo "  ${ICON_WARNING} $username - Account expired: $expiry"
                    ((expired++))
                elif [ "$((expiry_timestamp - current_timestamp))" -lt "$thirty_days" ]; then
                    echo "  ${ICON_WARNING} $username - Expires soon: $expiry"
                    ((expiring_soon++))
                fi
            fi
        fi
    done < /etc/passwd
    echo "  No expiration: $no_expiry | Expiring soon (30d): $expiring_soon | Expired: $expired"
    echo ""
    
    # Inactive accounts (no login > 90 days)
    echo "3. INACTIVE ACCOUNTS (No login > 90 days):"
    local inactive_count=0
    local threshold="${INACTIVE_THRESHOLD_DAYS:-90}"
    local ninety_days_ago=$(date -d "$threshold days ago" +%s)
    
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        local last_login_str=$(lastlog -u "$username" 2>/dev/null | tail -1 | awk '{if ($2 == "**") print "Never"; else print $4" "$5" "$6" "$7}')
        
        if [ "$last_login_str" = "Never" ]; then
            echo "  ${ICON_WARNING} $username - Never logged in"
            ((inactive_count++))
        elif [ "$last_login_str" != "Never" ]; then
            local last_login_timestamp=$(date -d "$last_login_str" +%s 2>/dev/null)
            if [ -n "$last_login_timestamp" ] && [ "$last_login_timestamp" -lt "$ninety_days_ago" ]; then
                echo "  ${ICON_WARNING} $username - Last login: $last_login_str"
                ((inactive_count++))
            fi
        fi
    done < /etc/passwd
    [ "$inactive_count" -eq 0 ] && echo "  ${ICON_SUCCESS} All accounts active within $threshold days"
    echo ""
    
    # Service accounts (nologin)
    echo "4. SERVICE ACCOUNTS:"
    local service_count=0
    while IFS=: read -r username _ uid _ _ _ shell; do
        is_regular_user "$uid" || continue
        if [[ "$shell" =~ nologin|false ]]; then
            local pwd_expiry=$(sudo chage -l "$username" 2>/dev/null | grep "Maximum number of days" | grep -oE '[0-9]+')
            if [ "$pwd_expiry" != "99999" ]; then
                echo "  ${ICON_WARNING} $username - Service account with password expiry (should be never)"
            else
                echo "  ${ICON_SUCCESS} $username - Properly configured"
            fi
            ((service_count++))
        fi
    done < /etc/passwd
    echo "  Total service accounts: $service_count"
    echo ""
    
    # Privileged accounts
    echo "5. PRIVILEGED ACCOUNTS:"
    local priv_count=0
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        if is_user_sudo "$username"; then
            local status=$(get_user_status "$username")
            local shell=$(getent passwd "$username" | cut -d: -f7)
            local pwd_expiry=$(sudo chage -l "$username" 2>/dev/null | grep "Password expires" | cut -d: -f2 | xargs)
            echo "  ${ICON_LOCK} $username"
            echo "      Status: $status | Shell: $(basename "$shell")"
            echo "      Password expires: $pwd_expiry"
            ((priv_count++))
        fi
    done < /etc/passwd
    echo "  Total privileged accounts: $priv_count"
    echo ""
    
    echo "=========================================="
    echo "COMPLIANCE SUMMARY:"
    echo "  Password policy compliant:    $compliant"
    echo "  Password policy non-compliant: $non_compliant"
    echo "  Inactive accounts (>${threshold}d):     $inactive_count"
    echo "  Service accounts:             $service_count"
    echo "  Privileged accounts:          $priv_count"
    echo "=========================================="
    
    log_action "report_compliance" "system" "SUCCESS" "Generated compliance report"
}

report_activity() {
    local days="${1:-30}"
    
    echo "=========================================="
    echo "Activity Report (Last $days days)"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    local cutoff_date=$(date -d "$days days ago" +%s)
    
    # Login frequency
    echo "1. LOGIN FREQUENCY:"
    declare -A login_counts
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        login_counts[$username]=0
    done < /etc/passwd
    
    # Count logins from last command
    while read -r line; do
        local user=$(echo "$line" | awk '{print $1}')
        local login_date=$(echo "$line" | awk '{print $4, $5, $7}')
        local login_timestamp=$(date -d "$login_date" +%s 2>/dev/null)
        
        if [ -n "$login_timestamp" ] && [ "$login_timestamp" -ge "$cutoff_date" ]; then
            if [ -n "${login_counts[$user]}" ]; then
                ((login_counts[$user]++))
            fi
        fi
    done < <(last -F -w | grep -v "^reboot" | grep -v "^wtmp" | tail -n +1)
    
    # Sort and display top 10
    echo "  Top 10 Most Active Users:"
    for user in "${!login_counts[@]}"; do
        echo "${login_counts[$user]} $user"
    done | sort -rn | head -10 | while read count user; do
        echo "    $user: $count logins"
    done
    echo ""
    
    # Inactive users
    echo "2. INACTIVE USERS (No login in last $days days):"
    local inactive_count=0
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        local last_login_str=$(lastlog -u "$username" 2>/dev/null | tail -1 | awk '{if ($2 == "**") print "Never"; else print $4" "$5" "$6" "$7}')
        
        if [ "$last_login_str" = "Never" ]; then
            echo "  ${ICON_WARNING} $username - Never logged in"
            ((inactive_count++))
        elif [ "$last_login_str" != "Never" ]; then
            local last_login_timestamp=$(date -d "$last_login_str" +%s 2>/dev/null)
            if [ -n "$last_login_timestamp" ] && [ "$last_login_timestamp" -lt "$cutoff_date" ]; then
                echo "  ${ICON_WARNING} $username - Last login: $last_login_str"
                ((inactive_count++))
            fi
        fi
    done < /etc/passwd
    [ "$inactive_count" -eq 0 ] && echo "  ${ICON_SUCCESS} All users active"
    echo ""
    
    # Failed login attempts
    echo "3. FAILED LOGIN ATTEMPTS (Last $days days):"
    if [ -f /var/log/auth.log ]; then
        local failed=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
        echo "  Total failed attempts: $failed"
        echo "  Top failed usernames:"
        grep "Failed password" /var/log/auth.log 2>/dev/null | grep -oP 'for \K[^ ]+' | sort | uniq -c | sort -rn | head -5 | while read count user; do
            echo "    $user: $count attempts"
        done
    elif [ -f /var/log/secure ]; then
        local failed=$(grep "Failed password" /var/log/secure 2>/dev/null | wc -l)
        echo "  Total failed attempts: $failed"
        echo "  Top failed usernames:"
        grep "Failed password" /var/log/secure 2>/dev/null | grep -oP 'for \K[^ ]+' | sort | uniq -c | sort -rn | head -5 | while read count user; do
            echo "    $user: $count attempts"
        done
    else
        echo "  ${ICON_INFO} Authentication log not available"
    fi
    echo ""
    
    # Account modifications
    echo "4. RECENT ACCOUNT MODIFICATIONS:"
    if [ -f "$LOG_FILE" ]; then
        local cutoff_date_str=$(date -d "$days days ago" +"%Y-%m-%d")
        grep -E "add_user|delete_user|update_user|lock_user|unlock_user" "$LOG_FILE" 2>/dev/null | \
            awk -v cutoff="$cutoff_date_str" '$0 >= "["cutoff {print}' | tail -20 | while read line; do
            echo "  $line"
        done
    else
        echo "  ${ICON_INFO} User management log not available"
    fi
    echo ""
    
    echo "=========================================="
    
    log_action "report_activity" "system" "SUCCESS" "Generated activity report for $days days"
}

report_storage() {
    echo "=========================================="
    echo "Storage Report"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    # Home directory sizes
    echo "1. TOP 10 LARGEST HOME DIRECTORIES:"
    declare -A home_sizes
    while IFS=: read -r username _ uid _ _ home _; do
        is_regular_user "$uid" || continue
        if [ -d "$home" ]; then
            local size=$(sudo du -sm "$home" 2>/dev/null | cut -f1)
            home_sizes[$username]=$size
        fi
    done < /etc/passwd
    
    for user in "${!home_sizes[@]}"; do
        echo "${home_sizes[$user]} $user"
    done | sort -rn | head -10 | while read size user; do
        echo "  $user: ${size}MB"
    done
    echo ""
    
    # Total storage by primary group
    echo "2. STORAGE BY PRIMARY GROUP:"
    declare -A group_sizes
    while IFS=: read -r username _ uid gid _ home _; do
        is_regular_user "$uid" || continue
        if [ -d "$home" ]; then
            local groupname=$(getent group "$gid" | cut -d: -f1)
            local size=$(sudo du -sm "$home" 2>/dev/null | cut -f1)
            if [ -n "${group_sizes[$groupname]}" ]; then
                group_sizes[$groupname]=$((${group_sizes[$groupname]} + size))
            else
                group_sizes[$groupname]=$size
            fi
        fi
    done < /etc/passwd
    
    for group in "${!group_sizes[@]}"; do
        echo "${group_sizes[$group]} $group"
    done | sort -rn | head -10 | while read size group; do
        echo "  $group: ${size}MB"
    done
    echo ""
    
    # Total storage used
    echo "3. TOTAL STORAGE SUMMARY:"
    local total_size=0
    for size in "${home_sizes[@]}"; do
        total_size=$((total_size + size))
    done
    echo "  Total home directories: ${total_size}MB ($(echo "scale=2; $total_size/1024" | bc)GB)"
    echo "  Number of users: ${#home_sizes[@]}"
    [ ${#home_sizes[@]} -gt 0 ] && echo "  Average per user: $((total_size / ${#home_sizes[@]}))MB"
    echo ""
    
    # Orphaned files (files with no valid owner)
    echo "4. ORPHANED FILES CHECK:"
    echo "  Scanning /home for orphaned files..."
    local orphaned=$(sudo find /home -nouser -o -nogroup 2>/dev/null | wc -l)
    if [ "$orphaned" -gt 0 ]; then
        echo "  ${ICON_WARNING} Found $orphaned orphaned files/directories"
        echo "  Top 10 locations:"
        sudo find /home -nouser -o -nogroup 2>/dev/null | head -10 | while read file; do
            echo "    $file"
        done
    else
        echo "  ${ICON_SUCCESS} No orphaned files found"
    fi
    echo ""
    
    # Large files in home directories
    echo "5. LARGE FILES (>100MB):"
    local large_files=$(sudo find /home -type f -size +100M 2>/dev/null | wc -l)
    if [ "$large_files" -gt 0 ]; then
        echo "  Found $large_files files larger than 100MB"
        echo "  Top 10 largest:"
        sudo find /home -type f -size +100M -exec du -h {} \; 2>/dev/null | sort -rh | head -10 | while read size file; do
            local owner=$(stat -c '%U' "$file" 2>/dev/null)
            echo "    $size - $file (owner: $owner)"
        done
    else
        echo "  ${ICON_SUCCESS} No files larger than 100MB"
    fi
    echo ""
    
    echo "=========================================="
    
    log_action "report_storage" "system" "SUCCESS" "Generated storage report"
}