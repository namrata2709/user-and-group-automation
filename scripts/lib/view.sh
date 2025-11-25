#!/usr/bin/env bash
# ===============================================
# View Module - Core Functions
# Version: 2.2.0
# ===============================================
# - Caching for performance
# - Advanced sorting (last-login, home-size)
# - Enhanced aggregation (sum, avg, min, max)
# - Date/regex in WHERE expressions
# - Validation view
# - Modular JSON output
# ===============================================

# --- Caching Mechanism ---
global_user_cache=()
global_group_cache=()
CACHE_TTL=${VIEW_CACHE_TTL:-300} # 5 minutes
USER_CACHE_FILE="/tmp/user_cache.dat"
GROUP_CACHE_FILE="/tmp/group_cache.dat"

load_cache() {
    local cache_file="$1"
    local -n cache_array=$2
    if [ -f "$cache_file" ] && [ $(($(date +%s) - $(stat -c %Y "$cache_file"))) -lt $CACHE_TTL ]; then
        mapfile -t cache_array < "$cache_file"
        log_action "INFO" "Loaded ${#cache_array[@]} records from $1 cache."
        return 0
    fi
    return 1
}

save_cache() {
    local cache_file="$1"
    local -n cache_array=$2
    printf '%s\n' "${cache_array[@]}" > "$cache_file"
    log_action "INFO" "Saved ${#cache_array[@]} records to $1 cache."
}

build_user_cache() {
    log_action "INFO" "Building user cache..."
    global_user_cache=()
    while IFS=: read -r username _ uid gid gecos home shell; do
        is_regular_user "$uid" || continue
        local user_data=$(build_user_data_object "$username" "$uid" "$gid" "$gecos" "$home" "$shell" "true")
        global_user_cache+=("$user_data")
    done < /etc/passwd
    save_cache "$USER_CACHE_FILE" global_user_cache
}

build_group_cache() {
    log_action "INFO" "Building group cache..."
    global_group_cache=()
    while IFS=: read -r groupname _ gid members; do
        is_system_group "$gid" && continue
        local group_data=$(build_group_data_object "$groupname" "$gid" "$members" "true")
        global_group_cache+=("$group_data")
    done < /etc/group
    save_cache "$GROUP_CACHE_FILE" global_group_cache
}

initialize_caches() {
    if ! load_cache "$USER_CACHE_FILE" global_user_cache; then
        build_user_cache
    fi
    if ! load_cache "$GROUP_CACHE_FILE" global_group_cache; then
        build_group_cache
    fi
}

# --- CORE FUNCTIONS (MODIFIED FOR CACHING) ---

get_users_data() {
    local filter="${1:-all}" search="$2" sort_by="${3:-username}" limit="${4:-0}" skip="${5:-0}" exclude="$6" \
          time_param="$7" in_group="$8" where_expr="$9" uid_range="${10}" home_size_range="${11}" \
          group_by="${12}" aggregate="${13}"

    initialize_caches
    
    local results=()
    for user_data in "${global_user_cache[@]}"; do
        local username=$(echo "$user_data" | grep -oP 'username=\K[^|]+')
        local uid=$(echo "$user_data" | grep -oP 'uid=\K[^|]+')

        if ! apply_user_filters "$username" "$uid" "$filter" "$exclude" "$time_param" "$in_group" "$where_expr" "$uid_range" "$home_size_range" "$user_data"; then
            continue
        fi
        
        if [ -n "$search" ] && ! match_pattern "$username" "$search"; then
            continue
        fi
        
        results+=("$user_data")
    done
    
    if [ -n "$group_by" ]; then
        aggregate_users "$group_by" "$aggregate" "${results[@]}"
        return
    fi
    
    results=($(sort_user_data "$sort_by" "${results[@]}"))
    results=($(paginate_results "$skip" "$limit" "${results[@]}"))
    
    printf '%s\n' "${results[@]}"
}

get_groups_data() {
    local filter="${1:-all}" search="$2" sort_by="${3:-groupname}" limit="${4:-0}" skip="${5:-0}" exclude="$6" \
          has_member="$7" where_expr="$8" gid_range="$9" member_count_range="${10}" \
          group_by="${11}" aggregate="${12}"

    initialize_caches

    local results=()
    for group_data in "${global_group_cache[@]}"; do
        local groupname=$(echo "$group_data" | grep -oP 'groupname=\K[^|]+')
        local gid=$(echo "$group_data" | grep -oP 'gid=\K[^|]+')
        local members=$(echo "$group_data" | grep -oP 'members=\K[^|]*')
        
        if ! apply_group_filters "$groupname" "$gid" "$members" "$filter" "$exclude" "$has_member" "$where_expr" "$gid_range" "$member_count_range" "$group_data"; then
            continue
        fi

        if [ -n "$search" ] && ! match_pattern "$groupname" "$search"; then
            continue
        fi

        results+=("$group_data")
    done

    if [ -n "$group_by" ]; then
        aggregate_groups "$group_by" "$aggregate" "${results[@]}"
        return
    fi

    results=($(sort_group_data "$sort_by" "${results[@]}"))
    results=($(paginate_results "$skip" "$limit" "${results[@]}"))

    printf '%s\n' "${results[@]}"
}

# --- HELPERS ---

apply_user_filters() {
    local username="$1" uid="$2" filter="$3" exclude="$4" time_param="$5" in_group="$6" where_expr="$7" uid_range="$8" home_size_range="$9" user_data="${10}"
    
    if [ -n "$filter" ] && [ "$filter" != "all" ]; then
        if ! eval_filter_expression "$username" "$uid" "$filter" "$time_param"; then
            return 1
        fi
    fi
    
    if [ -n "$exclude" ]; then
        if eval_filter_expression "$username" "$uid" "$exclude" "$time_param"; then
            return 1
        fi
    fi
    
    if [ -n "$in_group" ]; then
        if ! groups "$username" 2>/dev/null | grep -qw "$in_group"; then
            return 1
        fi
    fi
    
    if [ -n "$uid_range" ]; then
        if ! in_range "$uid" "$uid_range"; then
            return 1
        fi
    fi
    
    if [ -n "$home_size_range" ]; then
        local home_size_bytes=$(echo "$user_data" | grep -oP 'home_size_bytes=\K[^|]+')
        if ! in_range "$home_size_bytes" "$home_size_range"; then
            return 1
        fi
    fi
    
    if [ -n "$where_expr" ]; then
        declare -A data_map
        while IFS='|' read -ra pairs; do
            for pair in "${pairs[@]}"; do
                data_map[${pair%%=*}]="${pair#*=}"
            done
        done <<< "$user_data"
        
        local data_array=()
        for key in "${!data_map[@]}"; do
            data_array+=("$key=${data_map[$key]}")
        done

        if ! parse_where_expression "$where_expr" "${data_array[@]}"; then
            return 1
        fi
    fi
    
    return 0
}

apply_group_filters() {
    local groupname="$1" gid="$2" members="$3" filter="$4" exclude="$5" has_member="$6" where_expr="$7" gid_range="$8" member_count_range="$9" group_data="${10}"
    
    local member_count=0
    [ -n "$members" ] && member_count=$(echo "$members" | tr ',' '\n' | wc -l)
    
    if [ -n "$filter" ] && [ "$filter" != "all" ]; then
        if ! eval_group_filter_expression "$groupname" "$gid" "$members" "$member_count" "$filter"; then
            return 1
        fi
    fi
    
    if [ -n "$exclude" ]; then
        if eval_group_filter_expression "$groupname" "$gid" "$members" "$member_count" "$exclude"; then
            return 1
        fi
    fi
    
    if [ -n "$has_member" ]; then
        if ! echo "$members" | grep -qw "$has_member"; then
            return 1
        fi
    fi
    
    if [ -n "$gid_range" ]; then
        if ! in_range "$gid" "$gid_range"; then
            return 1
        fi
    fi
    
    if [ -n "$member_count_range" ]; then
        if ! in_range "$member_count" "$member_count_range"; then
            return 1
        fi
    fi
    
    if [ -n "$where_expr" ]; then
        declare -A data_map
        while IFS='|' read -ra pairs; do
            for pair in "${pairs[@]}"; do
                data_map[${pair%%=*}]="${pair#*=}"
            done
        done <<< "$group_data"
        
        local data_array=()
        for key in "${!data_map[@]}"; do
            data_array+=("$key=${data_map[$key]}")
        done

        if ! parse_where_expression "$where_expr" "${data_array[@]}"; then
            return 1
        fi
    fi
    
    return 0
}


build_user_data_object() {
    local username="$1" uid="$2" gid="$3" gecos="$4" home="$5" shell="$6" include_related="$7"

    local status=$(get_user_status "$username")
    local primary_group=$(id -gn "$username" 2>/dev/null)
    local last_login=$(get_last_login "$username")
    local last_login_ts=$(get_last_login_timestamp "$username")
    local home_size=$(get_home_size "$username")
    local home_size_bytes=$(du -sb "$home" 2>/dev/null | cut -f1)
    
    local has_sudo="false"
    is_user_sudo "$username" && has_sudo="true"
    local expires=$(get_account_expiry "$username")

    local data="username=$username|uid=$uid|gid=$gid|gecos=$gecos|primary_group=$primary_group|home=$home|shell=$shell|status=$status|last_login=$last_login|last_login_ts=$last_login_ts|home_size=$home_size|home_size_bytes=$home_size_bytes|sudo=$has_sudo|expires=$expires"
    
    if [ "$include_related" = "true" ]; then
        data="$data|groups=$(groups "$username" 2>/dev/null | cut -d: -f2- | xargs)"
    fi
    
    echo "$data"
}

build_group_data_object() {
    local groupname="$1" gid="$2" members="$3" include_related="$4"
    
    local member_count=0
    [ -n "$members" ] && member_count=$(echo "$members" | tr ',' '\n' | wc -l)
    
    local type="user"
    is_system_group "$gid" && type="system"
    
    local data="groupname=$groupname|gid=$gid|members=$members|member_count=$member_count|type=$type"
    
    if [ "$include_related" = "true" ] && [ -n "$members" ]; then
        local member_details=""
        IFS=',' read -ra member_array <<< "$members"
        for member in "${member_array[@]}"; do
            if id "$member" &>/dev/null; then
                local member_uid=$(id -u "$member")
                local member_status=$(get_user_status "$member")
                member_details+="$member:$member_uid:$member_status;"
            fi
        done
        data="$data|member_details=$member_details"
    fi
    
    echo "$data"
}

sort_user_data() {
    local sort_by="$1"; shift; local data=("$@")
    
    local sort_field
    case "$sort_by" in
        username) sort_field="username" ;;
        uid) sort_field="uid" ;;
        last-login) sort_field="last_login_ts" ;;
        home-size) sort_field="home_size_bytes" ;;
        *) printf '%s\n' "${data[@]}"; return ;;
    esac

    local is_numeric=false
    if [[ "$sort_by" == "uid" || "$sort_by" == "last-login" || "$sort_by" == "home-size" ]]; then
        is_numeric=true
    fi

    # Create a temporary file with sort keys
    local tmpfile=$(mktemp)
    for item in "${data[@]}"; do
        local key=$(echo "$item" | grep -oP "$sort_field=\K[^|]+")
        echo -e "$key\t$item" >> "$tmpfile"
    done

    if $is_numeric; then
        sort -t $'\t' -k1,1nr "$tmpfile" | cut -f2-
    else
        sort -t $'\t' -k1,1 "$tmpfile" | cut -f2-
    fi
    rm "$tmpfile"
}

sort_group_data() {
    local sort_by="$1"; shift; local data=("$@")
    
    case "$sort_by" in
        groupname)
            printf '%s\n' "${data[@]}" | sort -t'|' -k1
            ;;
        gid)
            printf '%s\n' "${data[@]}" | sort -t'|' -k2 -n
            ;;
        member-count)
            printf '%s\n' "${data[@]}" | sort -t'|' -k4 -n
            ;;
        *)
            printf '%s\n' "${data[@]}"
            ;;
    esac
}

paginate_results() {
    local skip="$1"
    local limit="$2"
    shift 2
    local data=("$@")
    
    local start=$((skip))
    local end=$((skip + limit))
    
    [ "$limit" -eq 0 ] && end=${#data[@]}
    
    local i=0
    for item in "${data[@]}"; do
        if [ "$i" -ge "$start" ]; then
            [ "$limit" -gt 0 ] && [ "$i" -ge "$end" ] && break
            echo "$item"
        fi
        ((i++))
    done
}

aggregate_users() {
    local group_by="$1"
    local aggregate_expr="$2"
    shift 2
    local data=("$@")

    declare -A groups
    
    IFS=',' read -ra agg_funcs <<< "$aggregate_expr"

    for item in "${data[@]}"; do
        local group_value=$(echo "$item" | grep -oP "$group_by=\K[^|]+")
        [ -z "$group_value" ] && group_value="(none)"
        groups["$group_value"]+="$item\n"
    done

    for group_key in "${!groups[@]}"; do
        local output="$group_by=$group_key"
        local group_items=${groups[$group_key]}
        local count=$(echo -e "$group_items" | wc -l)
        output+="|count=$count"

        for func in "${agg_funcs[@]}"; do
            # More robustly parse function and field, e.g., "sum(uid)"
            local op field
            if [[ "$func" =~ ([a-z]+) && "$func" =~ \((.*)\) ]]; then
                op="${func%%(*}"
                field="${func#*(}"
                field="${field%)*}"
            else
                continue
            fi

            local values=$(echo -e "$group_items" | grep -oP "$field=\\K[^|]+")
            
            local result
            case "$op" in
                sum) result=$(echo "$values" | paste -sd+ | bc) ;;
                avg)
                    local sum=$(echo "$values" | paste -sd+ | bc)
                    local num_values=$(echo "$values" | wc -l)
                    if [ "$num_values" -gt 0 ]; then
                        result=$(echo "scale=2; $sum / $num_values" | bc)
                    else
                        result=0
                    fi
                    ;;
                min) result=$(echo "$values" | sort -n | head -1) ;;
                max) result=$(echo "$values" | sort -n | tail -1) ;;
            esac
            output+="|${op}_${field}=${result:-0}"
        done
        echo "$output"
    done
}

aggregate_groups() {
    # This can be enhanced similarly to aggregate_users if needed
    local data=("${@:1:$#-2}")
    local group_by="${@: -2:1}"
    local aggregate="${@: -1}"
    
    declare -A groups
    declare -A counts
    
    for item in "${data[@]}"; do
        local group_value=$(echo "$item" | grep -oP "$group_by=\K[^|]+")
        groups["$group_value"]="${groups[$group_value]}$item\n"
        counts["$group_value"]=$((${counts[$group_value]:-0} + 1))
    done
    
    for group_key in "${!groups[@]}"; do
        echo "$group_by=$group_key|count=${counts[$group_key]}"
    done
}

validate_system() {
    log_action "INFO" "Running system validation checks..."
    local issues_found=0
    local output=""

    local root_users=$(awk -F: '($3 == 0) { print $1 }' /etc/passwd | tr '\n' ' ')
    if [ $(echo "$root_users" | wc -w) -gt 1 ]; then
        output+="[WARNING] Multiple root users found: $root_users\n"
        ((issues_found++))
    fi

    local duplicate_uids=$(cut -f3 -d: /etc/passwd | sort -n | uniq -d | tr '\n' ' ')
    if [ -n "$duplicate_uids" ]; then
        output+="[WARNING] Duplicate UIDs found: $duplicate_uids\n"
        ((issues_found++))
    fi

    local duplicate_gids=$(cut -f3 -d: /etc/group | sort -n | uniq -d | tr '\n' ' ')
    if [ -n "$duplicate_gids" ]; then
        output+="[WARNING] Duplicate GIDs found: $duplicate_gids\n"
        ((issues_found++))
    fi

    while IFS=: read -r user _ _ _ home _;
    do
        [ -n "$home" ] && [ ! -d "$home" ] && output+="[INFO] User '$user' has non-existent home: $home\n" && ((issues_found++))
    done < <(getent passwd | awk -F: '$3 >= 1000')

    if [ "$issues_found" -eq 0 ]; then
        echo -e "${ICON_SUCCESS} No system inconsistencies found." 
    else
        echo -e "${ICON_ERROR} Found $issues_found potential issue(s):\n$output"
    fi
}

# --- JSON Helper Functions ---
# Escape string for JSON
json_escape() {
    local string="$1"
    string="${string//\\/\\\\}"
    string="${string//\"/\\\"}"
    string="${string//$'\\t'/\\t}"
    string="${string//$'\\n'/\\n}"
    string="${string//$'\\r'/\\r}"
    echo "$string"
}

# Build JSON array from items
json_array() {
    local items=("$@")
    local result="["
    local first=true
    
    for item in "${items[@]}"; do
        [ "$first" = false ] && result+=","
        first=false
        result+="\"$(json_escape "$item")\""
    done
    
    result+="]"
    echo "$result"
}

# Build JSON object from key-value pairs
json_object() {
    local result="{"
    local first=true
    
    while [ $# -gt 0 ]; do
        local key="$1"
        local value="$2"
        shift 2
        
        [ "$first" = false ] && result+=","
        first=false
        
        if [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" =~ ^(true|false|null)$ ]]; then
            result+="\"$key\":$value"
        else
            result+="\"$key\":\"$(json_escape "$value")\""
        fi
    done
    
    result+="}"
    echo "$result"
}

# --- JSON Formatting Functions ---

format_users_json() {
    local data="$1"
    local columns="$2"
    local count_only="$3"

    if [ "$count_only" = true ]; then
        local count=0
        if [ -n "$data" ]; then
            count=$(echo "$data" | wc -l)
        fi
        echo "{\"count\": $count}"
        return
    fi

    echo "["
    local first=true
    
    while IFS= read -r line; do
        if [ -z "$line" ]; then continue; fi
        declare -A user_map
        while IFS='|' read -ra pairs; do
            for pair in "${pairs[@]}"; do
                user_map[${pair%%=*}]="${pair#*=}"
            done
        done <<< "$line"

        local groups_array="[]"
        if [ -n "${user_map[groups]}" ]; then
             groups_array="[$(echo "${user_map[groups]}" | tr ' ' '\n' | while read g; do echo "\"$g\""; done | paste -sd,)]"
        fi
        
        local expiry_json="null"
        if [ "${user_map[expires]}" != "Never" ] && [ -n "${user_map[expires]}" ]; then
            expiry_json="\"${user_map[expires]}\""
        fi

        [ "$first" = false ] && echo ","
        first=false

        cat << EOF
  {
    "username": "${user_map[username]}",
    "uid": ${user_map[uid]},
    "gid": ${user_map[gid]},
    "primary_group": "${user_map[primary_group]}",
    "groups": $groups_array,
    "home": "${user_map[home]}",
    "shell": "${user_map[shell]}",
    "status": "${user_map[status]}",
    "sudo": ${user_map[sudo]},
    "expires": $expiry_json
  }
EOF
    done <<< "$data"
    
    echo ""
    echo "]"
}

format_groups_json() {
    local data="$1"
    local columns="$2"
    local count_only="$3"

    if [ "$count_only" = true ]; then
        local count=0
        if [ -n "$data" ]; then
            count=$(echo "$data" | wc -l)
        fi
        echo "{\"count\": $count}"
        return
    fi

    echo "["
    local first=true
    
    while IFS= read -r line; do
        if [ -z "$line" ]; then continue; fi
        declare -A group_map
        while IFS='|' read -ra pairs; do
            for pair in "${pairs[@]}"; do
                group_map[${pair%%=*}]="${pair#*=}"
            done
        done <<< "$line"

        local members_array="[]"
        if [ -n "${group_map[members]}" ]; then
            members_array="[$(echo "${group_map[members]}" | sed 's/,/\", \"/g' | sed 's/^/\"/' | sed 's/$/\"/')]"
        fi

        [ "$first" = false ] && echo ","
        first=false

        cat << EOF
  {
    "groupname": "${group_map[groupname]}",
    "gid": ${group_map[gid]},
    "members": $members_array,
    "member_count": ${group_map[member_count]},
    "type": "${group_map[type]}"
  }
EOF
    done <<< "$data"
    
    echo ""
    echo "]"
}

format_user_details_json() {
    local data="$1"
    if [ -z "$data" ]; then return; fi
    
    declare -A user_map
    while IFS='|' read -ra pairs; do
        for pair in "${pairs[@]}"; do
            user_map[${pair%%=*}]="${pair#*=}"
        done
    done <<< "$data"

    local groups_array="[]"
    if [ -n "${user_map[groups]}" ]; then
         groups_array="[$(echo "${user_map[groups]}" | tr ' ' '\n' | while read g; do echo "\"$g\""; done | paste -sd,)]"
    fi
    
    local expiry_json="null"
    if [ "${user_map[expires]}" != "Never" ] && [ -n "${user_map[expires]}" ]; then
        expiry_json="\"${user_map[expires]}\""
    fi
    
    local last_login_json="null"
    if [ "${user_map[last_login]}" != "Never" ] && [ -n "${user_map[last_login]}" ]; then
        last_login_json="\"$(json_escape "${user_map[last_login]}")\""
    fi

    cat << EOF
{
  "username": "${user_map[username]}",
  "uid": ${user_map[uid]},
  "gid": ${user_map[gid]},
  "primary_group": "${user_map[primary_group]}",
  "groups": $groups_array,
  "home": "${user_map[home]}",
  "shell": "${user_map[shell]}",
  "comment": "$(json_escape "${user_map[gecos]}")",
  "status": "${user_map[status]}",
  "sudo": ${user_map[sudo]},
  "last_login": $last_login_json,
  "account_expires": $expiry_json,
  "home_size_bytes": ${user_map[home_size_bytes]:-0}
}
EOF
}

format_group_details_json() {
    local data="$1"
    if [ -z "$data" ]; then return; fi

    declare -A group_map
    while IFS='|' read -ra pairs; do
        for pair in "${pairs[@]}"; do
            group_map[${pair%%=*}]="${pair#*=}"
        done
    done <<< "$data"

    local members_array="[]"
    if [ -n "${group_map[members]}" ]; then
        members_array="[$(echo "${group_map[members]}" | sed 's/,/\", \"/g' | sed 's/^/\"/' | sed 's/$/\"/')]"
    fi

    cat << EOF
{
  "groupname": "${group_map[groupname]}",
  "gid": ${group_map[gid]},
  "members": $members_array,
  "member_count": ${group_map[member_count]},
  "type": "${group_map[type]}"
}
EOF
}