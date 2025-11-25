#!/usr/bin/env bash
# ===============================================
# JSON Report Module
# Version: 2.0.0
# ===============================================

# =============================================================================
# PRIVATE: _generate_json_report_header
# =============================================================================
_generate_json_report_header() {
    local report_type="$1"
    cat <<EOF
{
  "report_type": "$report_type",
  "generated_at": "$(date --iso-8601=seconds)",
  "hostname": "$(hostname)"
}
EOF
}

# =============================================================================
# PRIVATE: _array_to_json_array
# =============================================================================
_array_to_json_array() {
    local array_name="$1[@]"
    local array=("${!array_name}")
    local json_array=$(printf '"%s",' "${array[@]}")
    echo "[${json_array%,}]" # Remove trailing comma
}

# =============================================================================
# PUBLIC: report_security_json
# =============================================================================
report_security_json() {
    local header=$(_generate_json_report_header "security")
    local sudo_users=($(get_sudo_users))
    local locked_users=($(get_locked_users))
    local expired_passwords=($(get_users_with_expired_passwords))
    local no_expiry_users=($(get_users_without_password_expiry))

    local sudo_users_json=$(_array_to_json_array sudo_users)
    local locked_users_json=$(_array_to_json_array locked_users)
    local expired_passwords_json=$(_array_to_json_array expired_passwords)
    local no_expiry_users_json=$(_array_to_json_array no_expiry_users)

    local findings=$(cat <<EOF
{
  "sudo_users": {
    "count": ${#sudo_users[@]},
    "users": $sudo_users_json
  },
  "locked_accounts": {
    "count": ${#locked_users[@]},
    "users": $locked_users_json
  },
  "password_expiration": {
    "expired": {
      "count": ${#expired_passwords[@]},
      "users": $expired_passwords_json
    },
    "no_expiry_set": {
      "count": ${#no_expiry_users[@]},
      "users": $no_expiry_users_json
    }
  }
}
EOF
)

    echo "$header" | jq --argjson findings "$findings" '. + {findings: $findings}'
    log_action "report_security_json" "system" "SUCCESS" "Generated JSON security report."
}

# =============================================================================
# PUBLIC: report_compliance_json
# =============================================================================
report_compliance_json() {
    local header=$(_generate_json_report_header "compliance")
    local inactive_users=($(get_inactive_users 90))
    local inactive_users_json=$(_array_to_json_array inactive_users)
    
    # This is a simplified example. A real compliance report would be more complex.
    local findings=$(cat <<EOF
{
  "inactive_accounts": {
    "threshold_days": 90,
    "count": ${#inactive_users[@]},
    "users": $inactive_users_json
  }
}
EOF
)
    echo "$header" | jq --argjson findings "$findings" '. + {findings: $findings}'
    log_action "report_compliance_json" "system" "SUCCESS" "Generated JSON compliance report."
}

# =============================================================================
# PUBLIC: report_activity_json
# =============================================================================
report_activity_json() {
    local days="${1:-30}"
    local header=$(_generate_json_report_header "activity")
    local login_counts=$(get_login_counts "$days" | jq -sR 'split("\n") | .[:-1] | map(split(" ") | {user: .[1], logins: .[0] | tonumber})')

    local findings=$(cat <<EOF
{
  "login_frequency": {
    "period_days": $days,
    "top_users": $login_counts
  }
}
EOF
)
    echo "$header" | jq --argjson findings "$findings" '. + {findings: $findings}'
    log_action "report_activity_json" "system" "SUCCESS" "Generated JSON activity report."
}

# =============================================================================
# PUBLIC: report_storage_json
# =============================================================================
report_storage_json() {
    local header=$(_generate_json_report_header "storage")
    local top_users=$(get_top_storage_users 10 | jq -sR 'split("\n") | .[:-1] | map(split(" ") | {user: .[1], size: .[0]})')
    local orphaned_files=($(find_orphaned_files "/home"))
    local orphaned_files_json=$(_array_to_json_array orphaned_files)

    local findings=$(cat <<EOF
{
  "top_storage_users": $top_users,
  "orphaned_files": {
    "count": ${#orphaned_files[@]},
    "files": $orphaned_files_json
  }
}
EOF
)
    echo "$header" | jq --argjson findings "$findings" '. + {findings: $findings}'
    log_action "report_storage_json" "system" "SUCCESS" "Generated JSON storage report."
}