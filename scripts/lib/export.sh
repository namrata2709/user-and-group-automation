#!/usr/bin/env bash
# ===============================================
# Export Module
# Version: 2.0.0
# ===============================================
# Exports user and group data to various formats
# ===============================================

# =============================================================================
# PRIVATE: _get_all_users_data
# Description: Gathers all user data and outputs as a pipe-separated stream.
# Output Format: username|uid|primary_group|gid|home|shell|status|comment|last_login|groups
# =============================================================================
_get_all_users_data() {
    while IFS=: read -r username _ uid gid gecos home shell; do
        is_regular_user "$uid" || continue
        
        local status=$(get_user_status "$username")
        local primary_group=$(id -gn "$username" 2>/dev/null)
        local last_login=$(get_last_login "$username" | tr ' ' '_')
        local all_groups=$(groups "$username" 2>/dev/null | cut -d: -f2- | tr ' ' ';')
        local comment=$(echo "$gecos" | tr ',' ';')
        
        echo "$username|$uid|$primary_group|$gid|$home|$shell|$status|$comment|$last_login|$all_groups"
    done < /etc/passwd
}

# =============================================================================
# PRIVATE: _get_all_groups_data
# Description: Gathers all group data and outputs as a pipe-separated stream.
# Output Format: groupname|gid|type|members|member_count
# =============================================================================
_get_all_groups_data() {
    local min_gid="${MIN_GROUP_GID:-1000}"
    while IFS=: read -r groupname _ gid members; do
        [ "$gid" -lt "$min_gid" ] && continue
        
        local type="user"
        is_system_group "$groupname" && type="system"
        
        local member_count=0
        [ -n "$members" ] && member_count=$(echo "$members" | tr ',' '\n' | wc -l)
        
        echo "$groupname|$gid|$type|$members|$member_count"
    done < /etc/group
}

# =============================================================================
# PUBLIC: User Export Functions
# =============================================================================
export_users_csv() {
    local output_file="$1"
    echo "username,uid,primary_group,gid,home,shell,status,comment,last_login,groups" > "$output_file"
    _get_all_users_data | sed 's/|/,/g' >> "$output_file"
}

export_users_tsv() {
    local output_file="$1"
    echo -e "username\tuid\tprimary_group\tgid\thome\tshell\tstatus\tcomment\tlast_login\tgroups" > "$output_file"
    _get_all_users_data | sed 's/|/\t/g' >> "$output_file"
}

export_users_table() {
    local output_file="$1"
    {
        echo "=========================================="
        echo "User Export - Table Format"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "=========================================="
        echo ""
        printf "%-15s %-6s %-15s %-20s %-8s\n" "USERNAME" "UID" "PRIMARY_GROUP" "SHELL" "STATUS"
        echo "------------------------------------------------------------------------"
        
        _get_all_users_data | while IFS='|' read -r username uid primary_group _ _ shell status _; do
            local short_shell=$(basename "$shell")
            printf "%-15s %-6s %-15s %-20s %-8s\n" "$username" "$uid" "$primary_group" "$short_shell" "$status"
        done
        
        echo "------------------------------------------------------------------------"
    } > "$output_file"
}

export_users_json() {
    local output_file="$1"
    
    local users_json=$(_get_all_users_data | jq -R '
        split("|") | 
        {
            "username": .[0],
            "uid": .[1] | tonumber,
            "primary_group": .[2],
            "gid": .[3] | tonumber,
            "home": .[4],
            "shell": .[5],
            "status": .[6],
            "comment": .[7],
            "last_login": .[8],
            "groups": .[9] | split(";")
        }
    ' | jq -s '.')

    jq -n \
      --argjson users "$users_json" \
      --arg export_date "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg export_by "$USER" \
      '{
        "export_date": $export_date,
        "export_by": $export_by,
        "users": $users
      }' > "$output_file"
}

# =============================================================================
# PUBLIC: Group Export Functions
# =============================================================================
export_groups_csv() {
    local output_file="$1"
    echo "groupname,gid,type,members,member_count" > "$output_file"
    _get_all_groups_data | sed 's/|/,/g' >> "$output_file"
}

export_groups_tsv() {
    local output_file="$1"
    echo -e "groupname\tgid\ttype\tmembers\tmember_count" > "$output_file"
    _get_all_groups_data | sed 's/|/\t/g' >> "$output_file"
}

export_groups_table() {
    local output_file="$1"
    {
        echo "=========================================="
        echo "Group Export - Table Format"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "=========================================="
        echo ""
        printf "%-20s %-6s %-10s %-40s\n" "GROUPNAME" "GID" "TYPE" "MEMBERS"
        echo "------------------------------------------------------------------------"
        
        _get_all_groups_data | while IFS='|' read -r groupname gid type members _; do
            local member_display="${members:-none}"
            if [ ${#member_display} -gt 40 ]; then
                member_display="${member_display:0:37}..."
            fi
            printf "%-20s %-6s %-10s %-40s\n" "$groupname" "$gid" "$type" "$member_display"
        done
        
        echo "------------------------------------------------------------------------"
    } > "$output_file"
}

export_groups_json() {
    local output_file="$1"

    local groups_json=$(_get_all_groups_data | jq -R '
        split("|") |
        {
            "groupname": .[0],
            "gid": .[1] | tonumber,
            "type": .[2],
            "members": .[3] | split(","),
            "member_count": .[4] | tonumber
        }
    ' | jq -s '.')

    jq -n \
      --argjson groups "$groups_json" \
      --arg export_date "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg export_by "$USER" \
      '{
        "export_date": $export_date,
        "export_by": $export_by,
        "groups": $groups
      }' > "$output_file"
}

# =============================================================================
# PUBLIC: Combined Export Functions
# =============================================================================
export_all_json() {
    local output_file="$1"

    local users_json=$(_get_all_users_data | jq -R '
        split("|") | 
        {
            "username": .[0], "uid": .[1] | tonumber, "primary_group": .[2], "gid": .[3] | tonumber,
            "home": .[4], "shell": .[5], "status": .[6], "comment": .[7],
            "last_login": .[8], "groups": .[9] | split(";")
        }
    ' | jq -s '.')

    local groups_json=$(_get_all_groups_data | jq -R '
        split("|") |
        {
            "groupname": .[0], "gid": .[1] | tonumber, "type": .[2],
            "members": .[3] | split(","), "member_count": .[4] | tonumber
        }
    ' | jq -s '.')

    local min_uid="${MIN_USER_UID:-1000}"
    local max_uid="${MAX_USER_UID:-60000}"
    local min_gid="${MIN_GROUP_GID:-1000}"

    jq -n \
      --argjson users "$users_json" \
      --argjson groups "$groups_json" \
      --arg export_date "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg export_by "$USER" \
      --arg hostname "$(hostname)" \
      '{
        "export_date": $export_date,
        "export_by": $export_by,
        "hostname": $hostname,
        "system": {
            "total_users": ($users | length),
            "total_groups": ($groups | length)
        },
        "users": $users,
        "groups": $groups
      }' > "$output_file"
}

# =============================================================================
# PUBLIC: Main Export Dispatcher
# =============================================================================
export_data() {
    local export_type="$1"
    local output_file="$2"
    local format="${3:-table}"
    
    if [ -z "$output_file" ]; then
        error_message "Missing --output <file>"
        return 1
    fi
    
    display_banner "Exporting Data"
    info_message "Type:    $export_type"
    info_message "Format:  $format"
    info_message "Output:  $output_file"
    echo ""
    
    local export_function_name="export_${export_type}_${format}"

    if [[ "$export_type" == "all" && "$format" != "json" ]]; then
        error_message "'all' export only supports JSON format"
        return 1
    fi

    if declare -F "$export_function_name" > /dev/null; then
        "$export_function_name" "$output_file"
    else
        error_message "Invalid export type or format combination: $export_type, $format"
        info_message "Valid user formats: csv, json, table, tsv"
        info_message "Valid group formats: csv, json, table, tsv"
        info_message "Valid 'all' format: json"
        return 1
    fi
    
    if [ -f "$output_file" ]; then
        local file_size=$(du -h "$output_file" | cut -f1)
        success_message "Export complete"
        info_message "File: $output_file"
        info_message "Size: $file_size"
        log_action "export_$export_type" "$output_file" "SUCCESS" "format=$format, size=$file_size"
    else
        error_message "Export failed"
        log_action "export_$export_type" "$output_file" "FAILURE" "format=$format"
        return 1
    fi
}