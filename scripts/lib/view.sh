#!/usr/bin/env bash
# ================================================
# View Module - Core Functions
# Version: 2.0.0
# ================================================
# Complete rewrite with advanced features:
# - Pattern matching, filtering, sorting
# - Pagination, column selection, count-only
# - Range filters, custom WHERE expressions
# - Aggregation, tree views, validation
# ================================================

# ============================================
# CORE FUNCTION 1: get_users_data()
# ============================================
# Gets user data with all filters and parameters
# Args:
#   $1  - filter (all, active, locked, sudo, etc.)
#   $2  - search (pattern with wildcards)
#   $3  - sort_by (username, uid, last-login, home-size)
#   $4  - limit (0=unlimited)
#   $5  - skip (pagination offset)
#   $6  - exclude (filters to exclude, comma-separated)
#   $7  - time_param (for dynamic time filters)
#   $8  - in_group (filter by group membership)
#   $9  - where_expr (custom WHERE expression)
#   $10 - uid_range (UID range filter)
#   $11 - home_size_range (home size range)
#   $12 - group_by (aggregation grouping field)
#   $13 - aggregate (aggregation functions)
#   $14 - tree_by (hierarchical tree field)
#   $15 - include_related (include related data)
# Returns:
#   Array of user data (one user per line, fields separated by |)
get_users_data() {
    local filter="${1:-all}"
    local search="$2"
    local sort_by="${3:-username}"
    local limit="${4:-0}"
    local skip="${5:-0}"
    local exclude="$6"
    local time_param="$7"
    local in_group="$8"
    local where_expr="$9"
    local uid_range="${10}"
    local home_size_range="${11}"
    local group_by="${12}"
    local aggregate="${13}"
    local tree_by="${14}"
    local include_related="${15:-false}"
    
    local results=()
    local min_uid="${MIN_USER_UID:-1000}"
    local max_uid="${MAX_USER_UID:-60000}"
    
    # Process each user
    while IFS=: read -r username _ uid gid gecos home shell; do
        # Skip system users (UID < 1000)
        is_regular_user "$uid" || continue
        
        # Apply filters
        if ! apply_user_filters "$username" "$uid" "$filter" "$exclude" "$time_param" "$in_group" "$where_expr" "$uid_range" "$home_size_range"; then
            continue
        fi
        
        # Apply search pattern
        if [ -n "$search" ]; then
            if ! match_pattern "$username" "$search"; then
                continue
            fi
        fi
        
        # Build user data object
        local user_data=$(build_user_data_object "$username" "$uid" "$gid" "$gecos" "$home" "$shell" "$include_related")
        
        results+=("$user_data")
    done < /etc/passwd
    
    # Handle aggregation
    if [ -n "$group_by" ]; then
        aggregate_users "${results[@]}" "$group_by" "$aggregate"
        return $?
    fi
    
    # Handle tree view
    if [ -n "$tree_by" ]; then
        build_user_tree "${results[@]}" "$tree_by"
        return $?
    fi
    
    # Sort results
    if [ -n "$sort_by" ]; then
        results=($(sort_user_data "$sort_by" "${results[@]}"))
    fi
    
    # Apply pagination
    if [ "$skip" -gt 0 ] || [ "$limit" -gt 0 ]; then
        results=($(paginate_results "$skip" "$limit" "${results[@]}"))
    fi
    
    # Return results
    printf '%s\n' "${results[@]}"
}

# ============================================
# CORE FUNCTION 2: get_groups_data()
# ============================================
# Gets group data with all filters and parameters
# Args:
#   $1  - filter (all, empty, single, large, etc.)
#   $2  - search (pattern with wildcards)
#   $3  - sort_by (groupname, gid, member-count)
#   $4  - limit (0=unlimited)
#   $5  - skip (pagination offset)
#   $6  - exclude (filters to exclude)
#   $7  - has_member (filter by member existence)
#   $8  - where_expr (custom WHERE expression)
#   $9  - gid_range (GID range filter)
#   $10 - member_count_range (member count range)
#   $11 - group_by (aggregation grouping)
#   $12 - aggregate (aggregation functions)
#   $13 - include_related (include related data)
# Returns:
#   Array of group data (one group per line)
get_groups_data() {
    local filter="${1:-all}"
    local search="$2"
    local sort_by="${3:-groupname}"
    local limit="${4:-0}"
    local skip="${5:-0}"
    local exclude="$6"
    local has_member="$7"
    local where_expr="$8"
    local gid_range="$9"
    local member_count_range="${10}"
    local group_by="${11}"
    local aggregate="${12}"
    local include_related="${13:-false}"
    
    local results=()
    local min_gid="${MIN_GROUP_GID:-1000}"
    
    # Process each group
    while IFS=: read -r groupname _ gid members; do
        # Skip system groups (GID < 1000)
        [ "$gid" -lt "$min_gid" ] && continue
        
        # Apply filters
        if ! apply_group_filters "$groupname" "$gid" "$members" "$filter" "$exclude" "$has_member" "$where_expr" "$gid_range" "$member_count_range"; then
            continue
        fi
        
        # Apply search pattern
        if [ -n "$search" ]; then
            if ! match_pattern "$groupname" "$search"; then
                continue
            fi
        fi
        
        # Build group data object
        local group_data=$(build_group_data_object "$groupname" "$gid" "$members" "$include_related")
        
        results+=("$group_data")
    done < /etc/group
    
    # Handle aggregation
    if [ -n "$group_by" ]; then
        aggregate_groups "${results[@]}" "$group_by" "$aggregate"
        return $?
    fi
    
    # Sort results
    if [ -n "$sort_by" ]; then
        results=($(sort_group_data "$sort_by" "${results[@]}"))
    fi
    
    # Apply pagination
    if [ "$skip" -gt 0 ] || [ "$limit" -gt 0 ]; then
        results=($(paginate_results "$skip" "$limit" "${results[@]}"))
    fi
    
    # Return results
    printf '%s\n' "${results[@]}"
}

# ============================================
# CORE FUNCTION 3: get_user_details()
# ============================================
# Gets complete details for a single user
# Args:
#   $1 - username
#   $2 - include_recent_logins (true/false)
#   $3 - recent_login_hours (default 24)
# Returns:
#   Complete user data object
get_user_details() {
    local username="$1"
    local include_recent_logins="${2:-true}"
    local recent_login_hours="${3:-24}"
    
    if ! id "$username" &>/dev/null; then
        return 1
    fi
    
    local uid=$(id -u "$username")
    local gid=$(id -g "$username")
    local primary_group=$(id -gn "$username")
    local home=$(eval echo ~"$username")
    local shell=$(getent passwd "$username" | cut -d: -f7)
    local gecos=$(getent passwd "$username" | cut -d: -f5)
    
    # Basic info
    local status=$(get_user_status "$username")
    local last_login=$(get_last_login "$username")
    local acc_expires=$(get_account_expiry "$username")
    
    # Groups
    local all_groups=$(groups "$username" | cut -d: -f2- | xargs)
    
    # Resources
    local home_size=$(get_home_size "$username")
    local home_size_bytes=$(get_home_size_bytes "$username")
    local proc_count=$(($(count_user_processes "$username") - 1))
    [ "$proc_count" -lt 0 ] && proc_count=0
    local cron_count=$(count_user_cron_jobs "$username")
    
    # Sudo check
    local has_sudo="false"
    is_user_sudo "$username" && has_sudo="true"
    
    # Recent logins (if requested)
    local recent_logins=""
    if [ "$include_recent_logins" = "true" ]; then
        recent_logins=$(get_recent_logins_for_user "$username" "$recent_login_hours")
    fi
    
    # Build complete data object
    echo "username=$username|uid=$uid|gid=$gid|primary_group=$primary_group|home=$home|shell=$shell|gecos=$gecos|status=$status|last_login=$last_login|acc_expires=$acc_expires|groups=$all_groups|home_size=$home_size|home_size_bytes=$home_size_bytes|processes=$proc_count|cron_jobs=$cron_count|has_sudo=$has_sudo|recent_logins=$recent_logins"
}

# ============================================
# CORE FUNCTION 4: get_group_details()
# ============================================
# Gets complete details for a single group
# Args:
#   $1 - groupname
# Returns:
#   Complete group data object
get_group_details() {
    local groupname="$1"
    
    if ! getent group "$groupname" &>/dev/null; then
        return 1
    fi
    
    local gid=$(get_group_gid "$groupname")
    local members=$(get_group_members "$groupname")
    
    local member_count=0
    [ -n "$members" ] && member_count=$(echo "$members" | tr ',' '\n' | wc -l)
    
    # Check if system group
    local type="user"
    is_system_group "$groupname" && type="system"
    
    # Find users with this as primary group
    local primary_users=$(find_users_with_primary_group "$groupname")
    local primary_count=0
    [ -n "$primary_users" ] && primary_count=$(echo "$primary_users" | wc -l)
    
    # Build complete data object
    echo "groupname=$groupname|gid=$gid|members=$members|member_count=$member_count|type=$type|primary_users=$primary_users|primary_count=$primary_count"
}

# ============================================
# CORE FUNCTION 5: get_system_summary()
# ============================================
# Gets system summary with optional detailed statistics
# Args:
#   $1 - detailed (true/false) - include statistics
# Returns:
#   System summary data object
get_system_summary() {
    local detailed="${1:-false}"
    
    local min_uid="${MIN_USER_UID:-1000}"
    local max_uid="${MAX_USER_UID:-60000}"
    local min_gid="${MIN_GROUP_GID:-1000}"
    
    # Count users
    local total_users=$(awk -F: -v min="$min_uid" -v max="$max_uid" '$3 >= min && $3 <= max' /etc/passwd | wc -l)
    local active_users=0
    local locked_users=0
    
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        local status=$(get_user_status "$username")
        [ "$status" = "ACTIVE" ] && ((active_users++))
        [ "$status" = "LOCKED" ] && ((locked_users++))
    done < /etc/passwd
    
    # Count groups
    local total_groups=$(awk -F: -v min="$min_gid" '$3 >= min' /etc/group | wc -l)
    local empty_groups=0
    
    while IFS=: read -r groupname _ gid members; do
        [ "$gid" -lt "$min_gid" ] && continue
        [ -z "$members" ] && ((empty_groups++))
    done < /etc/group
    
    # Count sudo users
    local sudo_users=0
    while IFS=: read -r username _ uid _; do
        is_regular_user "$uid" || continue
        is_user_sudo "$username" && ((sudo_users++))
    done < /etc/passwd
    
    # Shell distribution
    local bash_count=$(awk -F: -v min="$min_uid" '$7 == "/bin/bash" && $3 >= min' /etc/passwd | wc -l)
    local nologin_count=$(awk -F: -v min="$min_uid" '$7 ~ /nologin|false/ && $3 >= min' /etc/passwd | wc -l)
    
    # Basic summary
    local summary="total_users=$total_users|active_users=$active_users|locked_users=$locked_users|total_groups=$total_groups|empty_groups=$empty_groups|sudo_users=$sudo_users|bash_users=$bash_count|nologin_users=$nologin_count"
    
    # Detailed statistics (if requested)
    if [ "$detailed" = "true" ]; then
        local detailed_stats=$(calculate_detailed_statistics)
        summary="$summary|$detailed_stats"
    fi
    
    echo "$summary"
}

# ============================================
# HELPER: apply_user_filters()
# ============================================
apply_user_filters() {
    local username="$1"
    local uid="$2"
    local filter="$3"
    local exclude="$4"
    local time_param="$5"
    local in_group="$6"
    local where_expr="$7"
    local uid_range="$8"
    local home_size_range="$9"
    
    # Parse multiple filters (AND/OR logic)
    local filters_result=true
    if [ -n "$filter" ] && [ "$filter" != "all" ]; then
        if ! eval_filter_expression "$username" "$uid" "$filter" "$time_param"; then
            return 1
        fi
    fi
    
    # Apply exclude filters
    if [ -n "$exclude" ]; then
        if eval_filter_expression "$username" "$uid" "$exclude" "$time_param"; then
            return 1  # Exclude this user
        fi
    fi
    
    # Filter by group membership
    if [ -n "$in_group" ]; then
        if ! groups "$username" 2>/dev/null | grep -qw "$in_group"; then
            return 1
        fi
    fi
    
    # Apply UID range filter
    if [ -n "$uid_range" ]; then
        if ! in_range "$uid" "$uid_range"; then
            return 1
        fi
    fi
    
    # Apply home size range filter
    if [ -n "$home_size_range" ]; then
        local home_size=$(get_home_size_bytes "$username")
        if ! in_range "$home_size" "$home_size_range"; then
            return 1
        fi
    fi
    
    # Apply custom WHERE expression
    if [ -n "$where_expr" ]; then
        # Build data object for expression evaluation
        local data=(
            "username=$username"
            "uid=$uid"
            "status=$(get_user_status "$username")"
            "home_size=$(get_home_size_bytes "$username")"
            "last_login=$(days_since "$(get_last_login "$username")")"
        )
        
        if ! parse_where_expression "$where_expr" "${data[@]}"; then
            return 1
        fi
    fi
    
    return 0
}

# ============================================
# HELPER: apply_group_filters()
# ============================================
apply_group_filters() {
    local groupname="$1"
    local gid="$2"
    local members="$3"
    local filter="$4"
    local exclude="$5"
    local has_member="$6"
    local where_expr="$7"
    local gid_range="$8"
    local member_count_range="$9"
    
    local member_count=0
    [ -n "$members" ] && member_count=$(echo "$members" | tr ',' '\n' | wc -l)
    
    # Parse multiple filters
    if [ -n "$filter" ] && [ "$filter" != "all" ]; then
        if ! eval_group_filter_expression "$groupname" "$gid" "$members" "$member_count" "$filter"; then
            return 1
        fi
    fi
    
    # Apply exclude filters
    if [ -n "$exclude" ]; then
        if eval_group_filter_expression "$groupname" "$gid" "$members" "$member_count" "$exclude"; then
            return 1
        fi
    fi
    
    # Filter by member
    if [ -n "$has_member" ]; then
        if ! echo "$members" | grep -qw "$has_member"; then
            return 1
        fi
    fi
    
    # Apply GID range filter
    if [ -n "$gid_range" ]; then
        if ! in_range "$gid" "$gid_range"; then
            return 1
        fi
    fi
    
    # Apply member count range filter
    if [ -n "$member_count_range" ]; then
        if ! in_range "$member_count" "$member_count_range"; then
            return 1
        fi
    fi
    
    # Apply custom WHERE expression
    if [ -n "$where_expr" ]; then
        local data=(
            "groupname=$groupname"
            "gid=$gid"
            "member_count=$member_count"
        )
        
        if ! parse_where_expression "$where_expr" "${data[@]}"; then
            return 1
        fi
    fi
    
    return 0
}

# ============================================
# HELPER: eval_filter_expression()
# ============================================
# Evaluates filter expression with AND/OR logic
# Format: "filter1,filter2|filter3" = (filter1 AND filter2) OR filter3
eval_filter_expression() {
    local username="$1"
    local uid="$2"
    local filter_expr="$3"
    local time_param="$4"
    
    # Handle OR (|) - split and evaluate each part
    if [[ "$filter_expr" =~ \| ]]; then
        IFS='|' read -ra or_parts <<< "$filter_expr"
        for part in "${or_parts[@]}"; then
            if eval_filter_expression "$username" "$uid" "$part" "$time_param"; then
                return 0  # At least one part matches
            fi
        done
        return 1  # None matched
    fi
    
    # Handle AND (,) - all must match
    IFS=',' read -ra and_parts <<< "$filter_expr"
    for filter in "${and_parts[@]}"; then
        filter=$(trim "$filter")
        if ! check_single_filter "$username" "$uid" "$filter" "$time_param"; then
            return 1  # One failed, all fail
        fi
    done
    
    return 0  # All matched
}

# ============================================
# HELPER: check_single_filter()
# ============================================
check_single_filter() {
    local username="$1"
    local uid="$2"
    local filter="$3"
    local time_param="${4:-90}"  # Default 90 days
    
    local status=$(get_user_status "$username")
    local shell=$(getent passwd "$username" | cut -d: -f7)
    
    case "$filter" in
        # Status filters
        active) [ "$status" = "ACTIVE" ] ;;
        locked) [ "$status" = "LOCKED" ] ;;
        
        # Sudo filters
        sudo) is_user_sudo "$username" ;;
        no-sudo) ! is_user_sudo "$username" ;;
        
        # Shell filters
        bash) [[ "$shell" = "/bin/bash" ]] ;;
        noshell) [[ "$shell" =~ nologin|false ]] ;;
        
        # Login filters
        no-login) [ "$(get_last_login "$username")" = "Never" ] ;;
        inactive)
            local days=$(days_since "$(get_last_login "$username")")
            [ "$days" -ge "$time_param" ] || [ "$days" -eq -1 ]
            ;;
        active-sessions) [ -n "$(check_user_logged_in "$username")" ] ;;
        
        # Account expiry filters
        expired)
            local expiry=$(get_account_expiry "$username")
            [ "$expiry" != "Never" ] && ! date_in_future "$expiry"
            ;;
        expiring|expiring-soon)
            local expiry=$(get_account_expiry "$username")
            local days="${time_param:-30}"
            [ "$expiry" != "Never" ] && date_within_days "$expiry" "$days"
            ;;
        
        # Password filters
        password-expired)
            local pwd_exp=$(sudo chage -l "$username" 2>/dev/null | grep "Password expires" | cut -d: -f2 | xargs)
            [ "$pwd_exp" != "never" ] && ! date_in_future "$pwd_exp"
            ;;
        password-expiring)
            local pwd_exp=$(sudo chage -l "$username" 2>/dev/null | grep "Password expires" | cut -d: -f2 | xargs)
            local days="${time_param:-7}"
            [ "$pwd_exp" != "never" ] && date_within_days "$pwd_exp" "$days"
            ;;
        
        # Resource filters
        has-cron) [ "$(count_user_cron_jobs "$username")" -gt 0 ] ;;
        large-home)
            local size_bytes=$(get_home_size_bytes "$username")
            local threshold="${time_param:-1073741824}"  # Default 1GB
            [ "$size_bytes" -gt "$threshold" ]
            ;;
        
        all) return 0 ;;
        *) return 1 ;;  # Unknown filter
    esac
}

# ============================================
# HELPER: eval_group_filter_expression()
# ============================================
eval_group_filter_expression() {
    local groupname="$1"
    local gid="$2"
    local members="$3"
    local member_count="$4"
    local filter_expr="$5"
    
    # Handle OR (|)
    if [[ "$filter_expr" =~ \| ]]; then
        IFS='|' read -ra or_parts <<< "$filter_expr"
        for part in "${or_parts[@]}"; do
            if eval_group_filter_expression "$groupname" "$gid" "$members" "$member_count" "$part"; then
                return 0
            fi
        done
        return 1
    fi
    
    # Handle AND (,)
    IFS=',' read -ra and_parts <<< "$filter_expr"
    for filter in "${and_parts[@]}"; do
        filter=$(trim "$filter")
        if ! check_single_group_filter "$groupname" "$gid" "$members" "$member_count" "$filter"; then
            return 1
        fi
    done
    
    return 0
}

# ============================================
# HELPER: check_single_group_filter()
# ============================================
check_single_group_filter() {
    local groupname="$1"
    local gid="$2"
    local members="$3"
    local member_count="$4"
    local filter="$5"
    
    case "$filter" in
        empty) [ "$member_count" -eq 0 ] ;;
        single) [ "$member_count" -eq 1 ] ;;
        large) [ "$member_count" -gt 10 ] ;;
        no-primary)
            local primary=$(find_users_with_primary_group "$groupname")
            [ -z "$primary" ]
            ;;
        sudo-groups) [[ "$groupname" =~ ^(sudo|wheel|admin)$ ]] ;;
        all) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================
# HELPER: build_user_data_object()
# ============================================
build_user_data_object() {
    local username="$1"
    local uid="$2"
    local gid="$3"
    local gecos="$4"
    local home="$5"
    local shell="$6"
    local include_related="$7"
    
    local status=$(get_user_status "$username")
    local primary_group=$(id -gn "$username" 2>/dev/null)
    local last_login=$(get_last_login "$username")
    local home_size=$(get_home_size "$username")
    
    local data="username=$username|uid=$uid|gid=$gid|primary_group=$primary_group|home=$home|shell=$shell|status=$status|last_login=$last_login|home_size=$home_size"
    
    # Include related data (groups) if requested
    if [ "$include_related" = "true" ]; then
        local all_groups=$(groups "$username" 2>/dev/null | cut -d: -f2- | xargs)
        data="$data|groups=$all_groups"
    fi
    
    echo "$data"
}

# ============================================
# HELPER: build_group_data_object()
# ============================================
build_group_data_object() {
    local groupname="$1"
    local gid="$2"
    local members="$3"
    local include_related="$4"
    
    local member_count=0
    [ -n "$members" ] && member_count=$(echo "$members" | tr ',' '\n' | wc -l)
    
    local data="groupname=$groupname|gid=$gid|members=$members|member_count=$member_count"
    
    # Include related data (user details) if requested
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

# ============================================
# HELPER: sort_user_data()
# ============================================
sort_user_data() {
    local sort_by="$1"
    shift
    local data=("$@")
    
    case "$sort_by" in
        username)
            printf '%s\n' "${data[@]}" | sort -t'|' -k1
            ;;
        uid)
            printf '%s\n' "${data[@]}" | sort -t'|' -k2 -n
            ;;
        last-login)
            # Sort by login date (complex, skip for now - TODO)
            printf '%s\n' "${data[@]}"
            ;;
        home-size)
            # Sort by home size (complex, skip for now - TODO)
            printf '%s\n' "${data[@]}"
            ;;
        *)
            printf '%s\n' "${data[@]}"
            ;;
    esac
}

# ============================================
# HELPER: sort_group_data()
# ============================================
sort_group_data() {
    local sort_by="$1"
    shift
    local data=("$@")
    
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

# ============================================
# HELPER: paginate_results()
# ============================================
paginate_results() {
    local skip="$1"
    local limit="$2"
    shift 2
    local data=("$@")
    
    local start=$((skip))
    local end=$((skip + limit))
    
    # If limit is 0, show all from skip onwards
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

# ============================================
# HELPER: aggregate_users()
# ============================================
aggregate_users() {
    local data=("${@:1:$#-2}")
    local group_by="${@: -2:1}"
    local aggregate="${@: -1}"
    
    declare -A groups
    declare -A counts
    declare -A sums
    
    # Group data
    for item in "${data[@]}"; do
        local group_value=$(echo "$item" | grep -oP "$group_by=\K[^|]+")
        groups["$group_value"]="${groups[$group_value]}$item
"
        counts["$group_value"]=$((${counts[$group_value]:-0} + 1))
    done
    
    # Output aggregated results
    for group_key in "${!groups[@]}"; do
        echo "$group_by=$group_key|count=${counts[$group_key]}"
    done
}

# ============================================
# HELPER: aggregate_groups()
# ============================================
aggregate_groups() {
    local data=("${@:1:$#-2}")
    local group_by="${@: -2:1}"
    local aggregate="${@: -1}"
    
    declare -A groups
    declare -A counts
    
    # Group data
    for item in "${data[@]}"; do
        local group_value=$(echo "$item" | grep -oP "$group_by=\K[^|]+")
        groups["$group_value"]="${groups[$group_value]}$item
"
        counts["$group_value"]=$((${counts[$group_value]:-0} + 1))
    done
    
    # Output aggregated results
    for group_key in "${!groups[@]}"; do
        echo "$group_by=$group_key|count=${counts[$group_key]}"
    done
}

# ============================================

# ============================================
# DISPLAY FUNCTION 1: display_users()
# ============================================
# Displays user data in table format
# Args:
#   $1 - data (user data array as string, one per line)
#   $2 - columns (comma-separated column names, or empty for all)
#   $3 - count_only (true/false)
# Returns:
#   Formatted table output
# Examples:
#   display_users "$data" "" false
#   display_users "$data" "username,uid,status" false
#   display_users "$data" "" true
display_users() {
    local data="$1"
    local columns="$2"
    local count_only="${3:-false}"
    
    # Count results
    local count=0
    [ -n "$data" ] && count=$(echo "$data" | wc -l)
    
    # Count-only mode
    if [ "$count_only" = "true" ]; then
        echo "$count"
        return 0
    fi
    
    # No results
    if [ "$count" -eq 0 ]; then
        echo "${ICON_INFO} No users found"
        return 0
    fi
    
    # Define all available columns
    local all_columns="username,uid,primary_group,home,shell,status,last_login,home_size"
    
    # Use specified columns or all
    if [ -z "$columns" ]; then
        columns="$all_columns"
    fi
    
    # Parse column list
    IFS=',' read -ra col_array <<< "$columns"
    
    # Print header
    echo "=========================================="
    echo "Users (${count} found)"
    echo "=========================================="
    echo ""
    
    # Build header row
    local header=""
    for col in "${col_array[@]}"; do
        col=$(trim "$col")
        case "$col" in
            username) header+="$(printf '%-16s' 'USERNAME')" ;;
            uid) header+="$(printf '%-8s' 'UID')" ;;
            primary_group) header+="$(printf '%-16s' 'PRIMARY_GROUP')" ;;
            home) header+="$(printf '%-24s' 'HOME')" ;;
            shell) header+="$(printf '%-20s' 'SHELL')" ;;
            status) header+="$(printf '%-10s' 'STATUS')" ;;
            last_login) header+="$(printf '%-20s' 'LAST_LOGIN')" ;;
            home_size) header+="$(printf '%-12s' 'HOME_SIZE')" ;;
            groups) header+="$(printf '%-30s' 'GROUPS')" ;;
        esac
    done
    
    echo "$header"
    echo "$(printf '%.0s-' {1..120})"
    
    # Print data rows
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        # Parse data object (format: key=value|key=value|...)
        declare -A user_data
        while IFS='|' read -ra pairs; do
            for pair in "${pairs[@]}"; do
                local key="${pair%%=*}"
                local value="${pair#*=}"
                user_data[$key]="$value"
            done
        done <<< "$line"
        
        # Build output row
        local row=""
        for col in "${col_array[@]}"; do
            col=$(trim "$col")
            local value="${user_data[$col]:-}"
            
            case "$col" in
                username)
                    row+="$(printf '%-16s' "${value:0:15}")"
                    ;;
                uid)
                    row+="$(printf '%-8s' "$value")"
                    ;;
                primary_group)
                    row+="$(printf '%-16s' "${value:0:15}")"
                    ;;
                home)
                    row+="$(printf '%-24s' "${value:0:23}")"
                    ;;
                shell)
                    local short_shell=$(basename "$value")
                    row+="$(printf '%-20s' "${short_shell:0:19}")"
                    ;;
                status)
                    if [ "$value" = "LOCKED" ]; then
                        row+="$(printf '\033[0;31m%-10s\033[0m' "$value")"  # Red
                    else
                        row+="$(printf '\033[0;32m%-10s\033[0m' "$value")"  # Green
                    fi
                    ;;
                last_login)
                    [ "$value" = "Never" ] && value="Never" || value="${value:0:19}"
                    row+="$(printf '%-20s' "$value")"
                    ;;
                home_size)
                    row+="$(printf '%-12s' "$value")"
                    ;;
                groups)
                    row+="$(printf '%-30s' "${value:0:29}")"
                    ;;
            esac
        done
        
        echo "$row"
        
        # Clear associative array for next iteration
        unset user_data
        declare -A user_data
        
    done <<< "$data"
    
    echo "$(printf '%.0s-' {1..120})"
    echo "Total: $count user(s)"
}

# ============================================
# DISPLAY FUNCTION 2: display_groups()
# ============================================
# Displays group data in table format
# Args:
#   $1 - data (group data array as string, one per line)
#   $2 - columns (comma-separated column names, or empty for all)
#   $3 - count_only (true/false)
# Returns:
#   Formatted table output
display_groups() {
    local data="$1"
    local columns="$2"
    local count_only="${3:-false}"
    
    # Count results
    local count=0
    [ -n "$data" ] && count=$(echo "$data" | wc -l)
    
    # Count-only mode
    if [ "$count_only" = "true" ]; then
        echo "$count"
        return 0
    fi
    
    # No results
    if [ "$count" -eq 0 ]; then
        echo "${ICON_INFO} No groups found"
        return 0
    fi
    
    # Define all available columns
    local all_columns="groupname,gid,member_count,members"
    
    # Use specified columns or all
    if [ -z "$columns" ]; then
        columns="$all_columns"
    fi
    
    # Parse column list
    IFS=',' read -ra col_array <<< "$columns"
    
    # Print header
    echo "=========================================="
    echo "Groups (${count} found)"
    echo "=========================================="
    echo ""
    
    # Build header row
    local header=""
    for col in "${col_array[@]}"; do
        col=$(trim "$col")
        case "$col" in
            groupname) header+="$(printf '%-20s' 'GROUPNAME')" ;;
            gid) header+="$(printf '%-8s' 'GID')" ;;
            member_count) header+="$(printf '%-14s' 'MEMBER_COUNT')" ;;
            members) header+="$(printf '%-50s' 'MEMBERS')" ;;
        esac
    done
    
    echo "$header"
    echo "$(printf '%.0s-' {1..100})"
    
    # Print data rows
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        # Parse data object
        declare -A group_data
        while IFS='|' read -ra pairs; do
            for pair in "${pairs[@]}"; do
                local key="${pair%%=*}"
                local value="${pair#*=}"
                group_data[$key]="$value"
            done
        done <<< "$line"
        
        # Build output row
        local row=""
        for col in "${col_array[@]}"; do
            col=$(trim "$col")
            local value="${group_data[$col]:-}"
            
            case "$col" in
                groupname)
                    row+="$(printf '%-20s' "${value:0:19}")"
                    ;;
                gid)
                    row+="$(printf '%-8s' "$value")"
                    ;;
                member_count)
                    if [ "$value" -eq 0 ]; then
                        row+="$(printf '\033[0;33m%-14s\033[0m' "$value (empty)")"  # Yellow
                    else
                        row+="$(printf '%-14s' "$value")"
                    fi
                    ;;
                members)
                    local members_display="${value:-none}"
                    [ ${#members_display} -gt 50 ] && members_display="${members_display:0:47}..."
                    row+="$(printf '%-50s' "$members_display")"
                    ;;
            esac
        done
        
        echo "$row"
        
        unset group_data
        declare -A group_data
        
    done <<< "$data"
    
    echo "$(printf '%.0s-' {1..100})"
    echo "Total: $count group(s)"
}

# ============================================
# DISPLAY FUNCTION 3: display_user_details()
# ============================================
# Displays detailed information for a single user
# Args:
#   $1 - data (single user data object)
# Returns:
#   Formatted detailed output
display_user_details() {
    local data="$1"
    
    # Parse data object
    declare -A user_data
    while IFS='|' read -ra pairs; do
        for pair in "${pairs[@]}"; do
            local key="${pair%%=*}"
            local value="${pair#*=}"
            user_data[$key]="$value"
        done
    done <<< "$data"
    
    local username="${user_data[username]}"
    
    echo "=========================================="
    echo "User Details: $username"
    echo "=========================================="
    echo ""
    
    # Basic Information
    echo "${ICON_USER} BASIC INFORMATION:"
    echo "  Username:      $username"
    echo "  UID:           ${user_data[uid]}"
    echo "  Primary Group: ${user_data[primary_group]} (GID: ${user_data[gid]})"
    echo "  Home:          ${user_data[home]}"
    echo "  Shell:         ${user_data[shell]}"
    echo "  Comment:       ${user_data[gecos]:-none}"
    echo ""
    
    # Status
    echo "${ICON_INFO} STATUS:"
    local status="${user_data[status]}"
    if [ "$status" = "LOCKED" ]; then
        echo "  Account:       ${ICON_LOCK} LOCKED"
    else
        echo "  Account:       ${ICON_SUCCESS} ACTIVE"
    fi
    
    local has_sudo="${user_data[has_sudo]}"
    if [ "$has_sudo" = "true" ]; then
        echo "  Sudo Access:   ${ICON_WARNING} YES"
    else
        echo "  Sudo Access:   No"
    fi
    
    echo "  Last Login:    ${user_data[last_login]}"
    echo "  Expires:       ${user_data[acc_expires]}"
    echo ""
    
    # Groups
    echo "${ICON_GROUP} GROUP MEMBERSHIPS:"
    local groups="${user_data[groups]}"
    if [ -n "$groups" ]; then
        echo "$groups" | tr ' ' '\n' | while read group; do
            [ -n "$group" ] && echo "  - $group"
        done
    else
        echo "  (none)"
    fi
    echo ""
    
    # Resources
    echo "ðŸ'¾ RESOURCES:"
    echo "  Home Size:     ${user_data[home_size]}"
    echo "  Processes:     ${user_data[processes]:-0}"
    echo "  Cron Jobs:     ${user_data[cron_jobs]:-0}"
    echo ""
    
    # Recent Logins (if available)
    if [ -n "${user_data[recent_logins]}" ]; then
        echo "ðŸ"… RECENT LOGINS:"
        local login_count=0
        while IFS='|' read -r timestamp tty from status duration; do
            [ -z "$timestamp" ] && continue
            ((login_count++))
            
            local date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "Unknown")
            local dur_formatted=$(format_duration "$duration")
            
            if [ "$status" = "active" ]; then
                echo "  ${ICON_SUCCESS} $date from $tty ($from) - Active ($dur_formatted)"
            else
                echo "  ${ICON_INFO} $date from $tty ($from) - $dur_formatted"
            fi
        done <<< "${user_data[recent_logins]}"
        
        [ "$login_count" -eq 0 ] && echo "  No recent logins"
        echo ""
    fi
    
    echo "=========================================="
}

# ============================================
# DISPLAY FUNCTION 4: display_group_details()
# ============================================
# Displays detailed information for a single group
# Args:
#   $1 - data (single group data object)
# Returns:
#   Formatted detailed output
display_group_details() {
    local data="$1"
    
    # Parse data object
    declare -A group_data
    while IFS='|' read -ra pairs; do
        for pair in "${pairs[@]}"; do
            local key="${pair%%=*}"
            local value="${pair#*=}"
            group_data[$key]="$value"
        done
    done <<< "$data"
    
    local groupname="${group_data[groupname]}"
    
    echo "=========================================="
    echo "Group Details: $groupname"
    echo "=========================================="
    echo ""
    
    echo "${ICON_GROUP} BASIC INFORMATION:"
    echo "  Group Name:    $groupname"
    echo "  GID:           ${group_data[gid]}"
    echo "  Type:          ${group_data[type]}"
    echo ""
    
    echo "${ICON_USER} MEMBERS:"
    local members="${group_data[members]}"
    local member_count="${group_data[member_count]}"
    
    if [ "$member_count" -gt 0 ]; then
        echo "  Count: $member_count"
        echo ""
        echo "$members" | tr ',' '\n' | while read member; do
            [ -n "$member" ] && echo "  - $member"
        done
    else
        echo "  ${ICON_WARNING} No members"
    fi
    echo ""
    
    echo "ðŸ'¤ PRIMARY GROUP FOR:"
    local primary_users="${group_data[primary_users]}"
    local primary_count="${group_data[primary_count]:-0}"
    
    if [ "$primary_count" -gt 0 ]; then
        echo "  Count: $primary_count"
        echo ""
        echo "$primary_users" | while read user; do
            [ -n "$user" ] && echo "  - $user"
        done
    else
        echo "  (none)"
    fi
    echo ""
    
    echo "=========================================="
}

# ============================================
# DISPLAY FUNCTION 5: display_system_summary()
# ============================================
# Displays system summary with optional detailed statistics
# Args:
#   $1 - data (summary data object)
#   $2 - detailed (true/false)
# Returns:
#   Formatted summary output
display_system_summary() {
    local data="$1"
    local detailed="${2:-false}"
    
    # Parse data object
    declare -A summary_data
    while IFS='|' read -ra pairs; do
        for pair in "${pairs[@]}"; do
            local key="${pair%%=*}"
            local value="${pair#*=}"
            summary_data[$key]="$value"
        done
    done <<< "$data"
    
    echo "=========================================="
    echo "System Summary"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    # Users
    echo "${ICON_USER} USERS:"
    echo "  Total:         ${summary_data[total_users]}"
    echo "  Active:        ${summary_data[active_users]}"
    echo "  Locked:        ${summary_data[locked_users]}"
    echo "  Sudo Access:   ${summary_data[sudo_users]}"
    echo ""
    
    # Groups
    echo "${ICON_GROUP} GROUPS:"
    echo "  Total:         ${summary_data[total_groups]}"
    echo "  Empty:         ${summary_data[empty_groups]}"
    echo ""
    
    # Shells
    echo "ðŸš SHELLS:"
    echo "  Bash:          ${summary_data[bash_users]}"
    echo "  Nologin:       ${summary_data[nologin_users]}"
    echo ""
    
    # Detailed statistics
    if [ "$detailed" = "true" ]; then
        echo "=========================================="
        echo "DETAILED STATISTICS"
        echo "=========================================="
        echo ""
        
        # UID Statistics
        echo "ðŸ"¢ UID STATISTICS:"
        echo "  Range:         ${summary_data[uid_min]:-N/A} - ${summary_data[uid_max]:-N/A}"
        echo "  Average:       ${summary_data[uid_avg]:-N/A}"
        echo "  Median:        ${summary_data[uid_median]:-N/A}"
        echo ""
        
        # Home Directory Statistics
        echo "ðŸ'¾ HOME DIRECTORIES:"
        echo "  Total Size:    ${summary_data[total_home_mb]:-0} MB"
        echo "  Average:       ${summary_data[home_avg_mb]:-0} MB"
        echo "  Range:         ${summary_data[home_min_mb]:-0} - ${summary_data[home_max_mb]:-0} MB"
        echo ""
        
        # Group Statistics
        echo "${ICON_GROUP} GROUP STATISTICS:"
        echo "  Empty:         ${summary_data[empty_groups]:-0}"
        echo "  Single Member: ${summary_data[single_member_groups]:-0}"
        echo "  Large (>10):   ${summary_data[large_groups]:-0}"
        echo "  Avg Members:   ${summary_data[member_avg]:-0}"
        echo "  Max Members:   ${summary_data[member_max]:-0}"
        echo ""
        
        # Shell Distribution
        echo "ðŸš SHELL DISTRIBUTION:"
        echo "  Bash:          ${summary_data[bash_users]:-0}"
        echo "  Sh:            ${summary_data[sh_users]:-0}"
        echo "  Zsh:           ${summary_data[zsh_users]:-0}"
        echo "  Nologin:       ${summary_data[nologin_users]:-0}"
        echo "  Other:         ${summary_data[other_shell_users]:-0}"
        echo ""
        
        # Login Activity
        echo "ðŸ"… LOGIN ACTIVITY:"
        echo "  Never:         ${summary_data[never_logged_in]:-0}"
        echo "  Last Day:      ${summary_data[logged_in_last_day]:-0}"
        echo "  Last Week:     ${summary_data[logged_in_last_week]:-0}"
        echo "  Last Month:    ${summary_data[logged_in_last_month]:-0}"
        echo "  Inactive:      ${summary_data[inactive_users]:-0}"
        echo ""
        
        # Password Policies
        echo "ðŸ"' PASSWORD POLICIES:"
        echo "  Never Expires: ${summary_data[pwd_never_expires]:-0}"
        echo "  30 Days:       ${summary_data[pwd_expires_30]:-0}"
        echo "  60 Days:       ${summary_data[pwd_expires_60]:-0}"
        echo "  90 Days:       ${summary_data[pwd_expires_90]:-0}"
        echo "  Custom:        ${summary_data[pwd_expires_custom]:-0}"
        echo ""
        
        # Active Resources
        echo "âš™ï¸  ACTIVE RESOURCES:"
        echo "  Users w/ Processes: ${summary_data[users_with_processes]:-0}"
        echo "  Total Processes:    ${summary_data[total_user_processes]:-0}"
        echo "  Users w/ Cron:      ${summary_data[users_with_cron]:-0}"
        echo "  Total Cron Jobs:    ${summary_data[total_cron_jobs]:-0}"
        echo ""
    fi
    
    echo "=========================================="
}

# ============================================
# HELPER: format_duration()
# ============================================
# Formats duration in seconds to human-readable format
# Args:
#   $1 - duration in seconds
# Returns:
#   Formatted string (e.g., "2h 30m")
format_duration() {
    local seconds="$1"
    
    if [ "$seconds" -lt 60 ]; then
        echo "${seconds}s"
    elif [ "$seconds" -lt 3600 ]; then
        local mins=$((seconds / 60))
        echo "${mins}m"
    elif [ "$seconds" -lt 86400 ]; then
        local hours=$((seconds / 3600))
        local mins=$(((seconds % 3600) / 60))
        echo "${hours}h ${mins}m"
    else
        local days=$((seconds / 86400))
        local hours=$(((seconds % 86400) / 3600))
        echo "${days}d ${hours}h"
    fi
}

# ============================================
# HELPER: display_user_groups()
# ============================================
# Displays groups for a user
# Args:
#   $1 - username
#   $2 - group data (filtered to this user)
# Returns:
#   Formatted group list
display_user_groups() {
    local username="$1"
    local data="$2"
    
    echo "=========================================="
    echo "Groups for User: $username"
    echo "=========================================="
    echo ""
    
    # Get primary group
    local primary_group=$(id -gn "$username" 2>/dev/null)
    local primary_gid=$(id -g "$username" 2>/dev/null)
    
    echo "${ICON_GROUP} PRIMARY GROUP:"
    echo "  $primary_group (GID: $primary_gid)"
    echo ""
    
    # Count secondary groups
    local count=0
    [ -n "$data" ] && count=$(echo "$data" | wc -l)
    
    echo "${ICON_GROUP} SECONDARY GROUPS: ($count)"
    
    if [ "$count" -gt 0 ]; then
        echo ""
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            
            # Parse group data
            declare -A group_data
            while IFS='|' read -ra pairs; do
                for pair in "${pairs[@]}"; do
                    local key="${pair%%=*}"
                    local value="${pair#*=}"
                    group_data[$key]="$value"
                done
            done <<< "$line"
            
            local groupname="${group_data[groupname]}"
            local gid="${group_data[gid]}"
            
            # Skip primary group
            [ "$groupname" = "$primary_group" ] && continue
            
            echo "  - $groupname (GID: $gid)"
            
            unset group_data
            declare -A group_data
        done <<< "$data"
    else
        echo "  (none)"
    fi
    
    echo ""
    echo "=========================================="
}

# ============================================
# HELPER: display_recent_logins()
# ============================================
# Displays recent login data
# Args:
#   $1 - login data (timestamp|tty|from|status|duration)
#   $2 - hours (for display header)
# Returns:
#   Formatted login table
display_recent_logins() {
    local data="$1"
    local hours="${2:-24}"
    
    # Count logins
    local count=0
    [ -n "$data" ] && count=$(echo "$data" | grep -c '|')
    
    echo "=========================================="
    echo "Recent Logins (Last $hours hours)"
    echo "=========================================="
    echo ""
    
    if [ "$count" -eq 0 ]; then
        echo "${ICON_INFO} No logins in the last $hours hours"
        return 0
    fi
    
    # Print header
    printf "%-16s %-20s %-24s %-12s %-12s\n" "USERNAME" "TIME" "FROM" "STATUS" "DURATION"
    echo "$(printf '%.0s-' {1..90})"
    
    # Print data rows
    while IFS='|' read -r username timestamp tty from status duration; do
        [ -z "$timestamp" ] && continue
        
        local date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "Unknown")
        local dur_formatted=$(format_duration "$duration")
        
        # Color code status
        local status_display
        if [ "$status" = "active" ]; then
            status_display="$(printf '\033[0;32m%-12s\033[0m' "$status")"  # Green
        else
            status_display="$(printf '%-12s' "$status")"
        fi
        
        printf "%-16s %-20s %-24s %b %-12s\n" \
            "${username:0:15}" \
            "$date" \
            "$from" \
            "$status_display" \
            "$dur_formatted"
    done <<< "$data"
    
    echo "$(printf '%.0s-' {1..90})"
    echo "Total: $count login(s)"
}