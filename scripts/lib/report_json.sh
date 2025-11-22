#!/usr/bin/env bash
# ================================================
# JSON Report Module
# Version: 1.0.1
# ================================================

report_security_json() {
    local sudo_users=()
    local locked_users=()
    local no_expiry_users=()
    local empty_groups=()
    
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        if is_user_sudo "$username"; then
            sudo_users+=("\"$username\"")
        fi
    done < /etc/passwd
    
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        if passwd -S "$username" 2>/dev/null | grep -q " LK "; then
            locked_users+=("\"$username\"")
        fi
    done < /etc/passwd
    
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        local max_days=$(sudo chage -l "$username" 2>/dev/null | grep "Maximum number of days" | awk '{print $NF}')
        local shell=$(getent passwd "$username" | cut -d: -f7)
        if [ "$max_days" = "99999" ] && [[ ! "$shell" =~ nologin|false ]]; then
            no_expiry_users+=("\"$username\"")
        fi
    done < /etc/passwd
    
    local min_gid="${MIN_GROUP_GID:-1000}"
    while IFS=: read -r groupname _ gid members; do
        [ "$gid" -lt "$min_gid" ] && continue
        if [ -z "$members" ]; then
            local primary_users=$(find_users_with_primary_group "$groupname")
            if [ -z "$primary_users" ]; then
                empty_groups+=("\"$groupname\"")
            fi
        fi
    done < /etc/group
    
    local total_findings=0
    local warnings=0
    local info=0
    
    [ ${#sudo_users[@]} -gt 5 ] && ((warnings++)) && ((total_findings++))
    [ ${#locked_users[@]} -gt 0 ] && ((info++)) && ((total_findings++))
    [ ${#no_expiry_users[@]} -gt 0 ] && ((warnings++)) && ((total_findings++))
    [ ${#empty_groups[@]} -gt 0 ] && ((info++)) && ((total_findings++))
    
    cat << EOF
{
  "report_type": "security",
  "generated": "$(date '+%Y-%m-%d %H:%M:%S')",
  "hostname": "$(hostname)",
  "findings": {
    "sudo_users": {
      "count": ${#sudo_users[@]},
      "users": [$(IFS=,; echo "${sudo_users[*]}")],
      "severity": "$([ ${#sudo_users[@]} -gt 5 ] && echo "warning" || echo "ok")"
    },
    "locked_accounts": {
      "count": ${#locked_users[@]},
      "users": [$(IFS=,; echo "${locked_users[*]}")],
      "severity": "info"
    },
    "no_password_expiry": {
      "count": ${#no_expiry_users[@]},
      "users": [$(IFS=,; echo "${no_expiry_users[*]}")],
      "severity": "$([ ${#no_expiry_users[@]} -gt 0 ] && echo "warning" || echo "ok")"
    },
    "empty_groups": {
      "count": ${#empty_groups[@]},
      "groups": [$(IFS=,; echo "${empty_groups[*]}")],
      "severity": "info"
    }
  },
  "summary": {
    "total_findings": $total_findings,
    "warnings": $warnings,
    "info": $info
  }
}
EOF
}

report_compliance_json() {
    local compliant=0
    local non_compliant=0
    local inactive_users=()
    local service_accounts=()
    local privileged_users=()
    
    local threshold_days="${INACTIVE_THRESHOLD_DAYS:-90}"
    local ninety_days_ago=$(date -d "$threshold_days days ago" +%s)
    
    while IFS=: read -r username _ uid _ _ _ shell; do
        is_regular_user "$uid" || continue
        
        local max_days=$(sudo chage -l "$username" 2>/dev/null | grep "Maximum number of days" | awk '{print $NF}')
        if [ "$max_days" -le 90 ]; then
            ((compliant++))
        else
            ((non_compliant++))
        fi
        
        if [[ "$shell" =~ nologin|false ]]; then
            service_accounts+=("\"$username\"")
        else
            local last_login=$(get_last_login "$username")
            if [ "$last_login" = "Never" ]; then
                inactive_users+=("\"$username\"")
            fi
        fi
        
        if is_user_sudo "$username"; then
            privileged_users+=("\"$username\"")
        fi
    done < /etc/passwd
    
    cat << EOF
{
  "report_type": "compliance",
  "generated": "$(date '+%Y-%m-%d %H:%M:%S')",
  "hostname": "$(hostname)",
  "findings": {
    "password_policy": {
      "standard": "max_90_days",
      "compliant": $compliant,
      "non_compliant": $non_compliant,
      "compliance_rate": $(awk "BEGIN {if ($compliant+$non_compliant > 0) printf \"%.2f\", ($compliant/($compliant+$non_compliant))*100; else print 0}")
    },
    "inactive_accounts": {
      "threshold_days": $threshold_days,
      "count": ${#inactive_users[@]},
      "users": [$(IFS=,; echo "${inactive_users[*]}")]
    },
    "service_accounts": {
      "count": ${#service_accounts[@]},
      "users": [$(IFS=,; echo "${service_accounts[*]}")]
    },
    "privileged_accounts": {
      "count": ${#privileged_users[@]},
      "users": [$(IFS=,; echo "${privileged_users[*]}")]
    }
  }
}
EOF
}

report_activity_json() {
    local days="${1:-30}"
    
    local active_users=()
    local inactive_users=()
    
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        local shell=$(getent passwd "$username" | cut -d: -f7)
        [[ "$shell" =~ nologin|false ]] && continue
        
        local last_login=$(get_last_login "$username")
        if [ "$last_login" = "Never" ]; then
            inactive_users+=("\"$username\"")
        else
            active_users+=("\"$username\"")
        fi
    done < /etc/passwd
    
    cat << EOF
{
  "report_type": "activity",
  "generated": "$(date '+%Y-%m-%d %H:%M:%S')",
  "hostname": "$(hostname)",
  "period_days": $days,
  "findings": {
    "active_users": {
      "count": ${#active_users[@]},
      "users": [$(IFS=,; echo "${active_users[*]}")]
    },
    "inactive_users": {
      "count": ${#inactive_users[@]},
      "users": [$(IFS=,; echo "${inactive_users[*]}")]
    }
  }
}
EOF
}

report_storage_json() {
    local users_data=()
    local total_size=0
    
    while IFS=: read -r username _ uid _ _ home _; do
        is_regular_user "$uid" || continue
        if [ -d "$home" ]; then
            local size=$(du -sb "$home" 2>/dev/null | cut -f1 || echo "0")
            local file_count=$(find "$home" -type f 2>/dev/null | wc -l || echo "0")
            total_size=$((total_size + size))
            
            users_data+=("{\"username\":\"$username\",\"home\":\"$home\",\"size_bytes\":$size,\"file_count\":$file_count}")
        fi
    done < /etc/passwd
    
    cat << EOF
{
  "report_type": "storage",
  "generated": "$(date '+%Y-%m-%d %H:%M:%S')",
  "hostname": "$(hostname)",
  "findings": {
    "users": [$(IFS=,; echo "${users_data[*]}")],
    "total_size_bytes": $total_size
  }
}
EOF
}