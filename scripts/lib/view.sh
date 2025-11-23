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