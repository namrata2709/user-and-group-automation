#!/usr/bin/env bash
# ================================================
# Export Module
# Version: 1.0.1
# ================================================
# Exports user and group data to various formats
# ================================================

export_users_csv() {
    local output_file="$1"
    
    echo "username,uid,primary_group,gid,home,shell,status,comment,last_login,groups" > "$output_file"
    
    while IFS=: read -r username _ uid gid gecos home shell; do
        is_regular_user "$uid" || continue
        
        local status=$(get_user_status "$username")
        local primary_group=$(id -gn "$username" 2>/dev/null)
        local last_login=$(get_last_login "$username" | tr ' ' '_')
        local all_groups=$(groups "$username" 2>/dev/null | cut -d: -f2- | tr ' ' ';')
        local comment=$(echo "$gecos" | tr ',' ';')
        
        echo "$username,$uid,$primary_group,$gid,$home,$shell,$status,\"$comment\",$last_login,\"$all_groups\"" >> "$output_file"
    done < /etc/passwd
}

export_users_json() {
    local output_file="$1"
    
    echo "{" > "$output_file"
    echo "  \"export_date\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> "$output_file"
    echo "  \"export_by\": \"$USER\"," >> "$output_file"
    echo "  \"users\": [" >> "$output_file"
    
    local first=true
    while IFS=: read -r username _ uid gid gecos home shell; do
        is_regular_user "$uid" || continue
        
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$output_file"
        fi
        
        local status=$(get_user_status "$username")
        local primary_group=$(id -gn "$username" 2>/dev/null)
        local last_login=$(get_last_login "$username")
        local all_groups=$(groups "$username" 2>/dev/null | cut -d: -f2- | sed 's/ /", "/g')
        
        cat >> "$output_file" <<EOF
    {
      "username": "$username",
      "uid": $uid,
      "gid": $gid,
      "primary_group": "$primary_group",
      "home": "$home",
      "shell": "$shell",
      "status": "$status",
      "comment": "$gecos",
      "last_login": "$last_login",
      "groups": ["$all_groups"]
    }
EOF
    done < /etc/passwd
    
    echo "" >> "$output_file"
    echo "  ]" >> "$output_file"
    echo "}" >> "$output_file"
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
        
        while IFS=: read -r username _ uid gid _ home shell; do
            is_regular_user "$uid" || continue
            
            local status=$(get_user_status "$username")
            local primary_group=$(id -gn "$username" 2>/dev/null)
            local short_shell=$(basename "$shell")
            
            printf "%-15s %-6s %-15s %-20s %-8s\n" "$username" "$uid" "$primary_group" "$short_shell" "$status"
        done < /etc/passwd
        
        echo "------------------------------------------------------------------------"
    } > "$output_file"
}

export_users_tsv() {
    local output_file="$1"
    
    echo -e "username\tuid\tprimary_group\tgid\thome\tshell\tstatus\tcomment\tlast_login\tgroups" > "$output_file"
    
    while IFS=: read -r username _ uid gid gecos home shell; do
        is_regular_user "$uid" || continue
        
        local status=$(get_user_status "$username")
        local primary_group=$(id -gn "$username" 2>/dev/null)
        local last_login=$(get_last_login "$username" | tr ' ' '_')
        local all_groups=$(groups "$username" 2>/dev/null | cut -d: -f2- | tr ' ' ';')
        
        echo -e "$username\t$uid\t$primary_group\t$gid\t$home\t$shell\t$status\t$gecos\t$last_login\t$all_groups" >> "$output_file"
    done < /etc/passwd
}

export_groups_csv() {
    local output_file="$1"
    
    echo "groupname,gid,type,members,member_count" > "$output_file"
    
    local min_gid="${MIN_GROUP_GID:-1000}"
    while IFS=: read -r groupname _ gid members; do
        [ "$gid" -lt "$min_gid" ] && continue
        
        local type="user"
        is_system_group "$groupname" && type="system"
        
        local member_count=0
        [ -n "$members" ] && member_count=$(echo "$members" | tr ',' '\n' | wc -l)
        
        echo "$groupname,$gid,$type,\"$members\",$member_count" >> "$output_file"
    done < /etc/group
}

export_groups_json() {
    local output_file="$1"
    
    echo "{" > "$output_file"
    echo "  \"export_date\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> "$output_file"
    echo "  \"export_by\": \"$USER\"," >> "$output_file"
    echo "  \"groups\": [" >> "$output_file"
    
    local first=true
    local min_gid="${MIN_GROUP_GID:-1000}"
    while IFS=: read -r groupname _ gid members; do
        [ "$gid" -lt "$min_gid" ] && continue
        
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$output_file"
        fi
        
        local type="user"
        is_system_group "$groupname" && type="system"
        
        local member_count=0
        local member_array=""
        if [ -n "$members" ]; then
            member_count=$(echo "$members" | tr ',' '\n' | wc -l)
            member_array=$(echo "$members" | sed 's/,/", "/g')
        fi
        
        cat >> "$output_file" <<EOF
    {
      "groupname": "$groupname",
      "gid": $gid,
      "type": "$type",
      "members": ["$member_array"],
      "member_count": $member_count
    }
EOF
    done < /etc/group
    
    echo "" >> "$output_file"
    echo "  ]" >> "$output_file"
    echo "}" >> "$output_file"
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
        
        local min_gid="${MIN_GROUP_GID:-1000}"
        while IFS=: read -r groupname _ gid members; do
            [ "$gid" -lt "$min_gid" ] && continue
            
            local type="user"
            is_system_group "$groupname" && type="system"
            
            local member_display="${members:-none}"
            if [ ${#member_display} -gt 40 ]; then
                member_display="${member_display:0:37}..."
            fi
            
            printf "%-20s %-6s %-10s %-40s\n" "$groupname" "$gid" "$type" "$member_display"
        done < /etc/group
        
        echo "------------------------------------------------------------------------"
    } > "$output_file"
}

export_groups_tsv() {
    local output_file="$1"
    
    echo -e "groupname\tgid\ttype\tmembers\tmember_count" > "$output_file"
    
    local min_gid="${MIN_GROUP_GID:-1000}"
    while IFS=: read -r groupname _ gid members; do
        [ "$gid" -lt "$min_gid" ] && continue
        
        local type="user"
        is_system_group "$groupname" && type="system"
        
        local member_count=0
        [ -n "$members" ] && member_count=$(echo "$members" | tr ',' '\n' | wc -l)
        
        echo -e "$groupname\t$gid\t$type\t$members\t$member_count" >> "$output_file"
    done < /etc/group
}

export_all_json() {
    local output_file="$1"
    
    local min_uid="${MIN_USER_UID:-1000}"
    local max_uid="${MAX_USER_UID:-60000}"
    local min_gid="${MIN_GROUP_GID:-1000}"
    
    echo "{" > "$output_file"
    echo "  \"export_date\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> "$output_file"
    echo "  \"export_by\": \"$USER\"," >> "$output_file"
    echo "  \"hostname\": \"$(hostname)\"," >> "$output_file"
    echo "  \"system\": {" >> "$output_file"
    echo "    \"total_users\": $(awk -F: -v min="$min_uid" -v max="$max_uid" '$3 >= min && $3 <= max' /etc/passwd | wc -l)," >> "$output_file"
    echo "    \"total_groups\": $(awk -F: -v min="$min_gid" '$3 >= min' /etc/group | wc -l)" >> "$output_file"
    echo "  }," >> "$output_file"
    echo "  \"users\": [" >> "$output_file"
    
    local first=true
    while IFS=: read -r username _ uid gid gecos home shell; do
        is_regular_user "$uid" || continue
        
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$output_file"
        fi
        
        local status=$(get_user_status "$username")
        local primary_group=$(id -gn "$username" 2>/dev/null)
        local last_login=$(get_last_login "$username")
        local all_groups=$(groups "$username" 2>/dev/null | cut -d: -f2- | sed 's/ /", "/g')
        
        cat >> "$output_file" <<EOF
    {
      "username": "$username",
      "uid": $uid,
      "gid": $gid,
      "primary_group": "$primary_group",
      "home": "$home",
      "shell": "$shell",
      "status": "$status",
      "comment": "$gecos",
      "last_login": "$last_login",
      "groups": ["$all_groups"]
    }
EOF
    done < /etc/passwd
    
    echo "" >> "$output_file"
    echo "  ]," >> "$output_file"
    echo "  \"groups\": [" >> "$output_file"
    
    first=true
    while IFS=: read -r groupname _ gid members; do
        [ "$gid" -lt "$min_gid" ] && continue
        
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$output_file"
        fi
        
        local type="user"
        is_system_group "$groupname" && type="system"
        
        local member_count=0
        local member_array=""
        if [ -n "$members" ]; then
            member_count=$(echo "$members" | tr ',' '\n' | wc -l)
            member_array=$(echo "$members" | sed 's/,/", "/g')
        fi
        
        cat >> "$output_file" <<EOF
    {
      "groupname": "$groupname",
      "gid": $gid,
      "type": "$type",
      "members": ["$member_array"],
      "member_count": $member_count
    }
EOF
    done < /etc/group
    
    echo "" >> "$output_file"
    echo "  ]" >> "$output_file"
    echo "}" >> "$output_file"
}

export_data() {
    local export_type="$1"
    local output_file="$2"
    local format="${3:-table}"
    
    if [ -z "$output_file" ]; then
        echo "${ICON_ERROR} Missing --output <file>"
        return 1
    fi
    
    echo "=========================================="
    echo "Exporting Data"
    echo "=========================================="
    echo "Type:    $export_type"
    echo "Format:  $format"
    echo "Output:  $output_file"
    echo ""
    
    case "$export_type" in
        users)
            case "$format" in
                csv) export_users_csv "$output_file" ;;
                json) export_users_json "$output_file" ;;
                table) export_users_table "$output_file" ;;
                tsv) export_users_tsv "$output_file" ;;
                *)
                    echo "${ICON_ERROR} Invalid format: $format"
                    echo "Use: csv, json, table, tsv"
                    return 1
                    ;;
            esac
            ;;
        groups)
            case "$format" in
                csv) export_groups_csv "$output_file" ;;
                json) export_groups_json "$output_file" ;;
                table) export_groups_table "$output_file" ;;
                tsv) export_groups_tsv "$output_file" ;;
                *)
                    echo "${ICON_ERROR} Invalid format: $format"
                    return 1
                    ;;
            esac
            ;;
        all)
            case "$format" in
                json) export_all_json "$output_file" ;;
                *)
                    echo "${ICON_ERROR} 'all' export only supports JSON format"
                    return 1
                    ;;
            esac
            ;;
        *)
            echo "${ICON_ERROR} Invalid export type: $export_type"
            echo "Use: users, groups, all"
            return 1
            ;;
    esac
    
    if [ -f "$output_file" ]; then
        local file_size=$(du -h "$output_file" | cut -f1)
        echo "${ICON_SUCCESS} Export complete"
        echo "  File: $output_file"
        echo "  Size: $file_size"
        
        log_action "export_$export_type" "$output_file" "SUCCESS" "format=$format, size=$file_size"
    else
        echo "${ICON_ERROR} Export failed"
        return 1
    fi
}