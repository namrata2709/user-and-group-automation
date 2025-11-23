#!/usr/bin/env bash
# ================================================
# Expression Parser Module
# Version: 2.0.0
# ================================================
# Full expression parser with AND, OR, NOT, parentheses
# Supports: =, !=, >, <, >=, <=, LIKE, NOT LIKE
# ================================================

# parse_where_expression()
# Parses and evaluates WHERE expression against data object
# Args:
#   $1 - expression string
#   $2+ - data object (field=value pairs)
# Returns:
#   0 if expression evaluates to true, 1 if false
# Example:
#   parse_where_expression "uid > 1500 AND status = active" "uid=1501" "status=active"
parse_where_expression() {
    local expression="$1"
    shift
    local data=("$@")
    
    # Empty expression = always true
    [ -z "$expression" ] && return 0
    
    # Parse data into associative array
    declare -A fields
    for item in "${data[@]}"; do
        local key="${item%%=*}"
        local value="${item#*=}"
        fields[$key]="$value"
    done
    
    # Evaluate expression
    eval_expression "$expression" fields
}

# eval_expression()
# Recursive expression evaluator
# Args:
#   $1 - expression
#   $2 - reference to fields associative array
# Returns:
#   0 if true, 1 if false
eval_expression() {
    local expr="$1"
    local -n fields_ref=$2
    
    # Remove leading/trailing whitespace
    expr=$(echo "$expr" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Handle parentheses (recursive)
    if [[ "$expr" =~ ^\(.*\)$ ]]; then
        # Remove outer parentheses
        expr="${expr:1:-1}"
        eval_expression "$expr" fields_ref
        return $?
    fi
    
    # Find top-level OR operator (lowest precedence)
    if contains_top_level_operator "$expr" "OR"; then
        local left right
        split_by_operator "$expr" "OR" left right
        
        eval_expression "$left" fields_ref || eval_expression "$right" fields_ref
        return $?
    fi
    
    # Find top-level AND operator
    if contains_top_level_operator "$expr" "AND"; then
        local left right
        split_by_operator "$expr" "AND" left right
        
        eval_expression "$left" fields_ref && eval_expression "$right" fields_ref
        return $?
    fi
    
    # Handle NOT operator
    if [[ "$expr" =~ ^NOT[[:space:]]+ ]]; then
        local inner="${expr#NOT }"
        inner=$(echo "$inner" | sed 's/^[[:space:]]*//')
        eval_expression "$inner" fields_ref
        # Invert result
        [ $? -eq 0 ] && return 1 || return 0
    fi
    
    # Base case: evaluate comparison
    eval_comparison "$expr" fields_ref
}

# contains_top_level_operator()
# Checks if expression contains operator at top level (not in parentheses)
# Args:
#   $1 - expression
#   $2 - operator (AND, OR)
# Returns:
#   0 if found, 1 if not found
contains_top_level_operator() {
    local expr="$1"
    local operator="$2"
    
    local paren_depth=0
    local i=0
    local len=${#expr}
    
    while [ $i -lt $len ]; do
        local char="${expr:$i:1}"
        
        case "$char" in
            '(') ((paren_depth++)) ;;
            ')') ((paren_depth--)) ;;
            *)
                if [ $paren_depth -eq 0 ]; then
                    # Check if operator starts here (case-insensitive)
                    local substr="${expr:$i:${#operator}}"
                    if [ "${substr^^}" = "$operator" ]; then
                        # Check word boundary (space before/after)
                        local before=" "
                        local after=" "
                        [ $i -gt 0 ] && before="${expr:$((i-1)):1}"
                        [ $((i + ${#operator})) -lt $len ] && after="${expr:$((i+${#operator})):1}"
                        
                        if [[ "$before" =~ [[:space:]] ]] && [[ "$after" =~ [[:space:]] ]]; then
                            return 0
                        fi
                    fi
                fi
                ;;
        esac
        ((i++))
    done
    
    return 1
}

# split_by_operator()
# Splits expression by top-level operator
# Args:
#   $1 - expression
#   $2 - operator (AND, OR)
#   $3 - variable name for left part
#   $4 - variable name for right part
split_by_operator() {
    local expr="$1"
    local operator="$2"
    local -n left_ref=$3
    local -n right_ref=$4
    
    local paren_depth=0
    local i=0
    local len=${#expr}
    
    while [ $i -lt $len ]; do
        local char="${expr:$i:1}"
        
        case "$char" in
            '(') ((paren_depth++)) ;;
            ')') ((paren_depth--)) ;;
            *)
                if [ $paren_depth -eq 0 ]; then
                    local substr="${expr:$i:${#operator}}"
                    if [ "${substr^^}" = "$operator" ]; then
                        local before=" "
                        local after=" "
                        [ $i -gt 0 ] && before="${expr:$((i-1)):1}"
                        [ $((i + ${#operator})) -lt $len ] && after="${expr:$((i+${#operator})):1}"
                        
                        if [[ "$before" =~ [[:space:]] ]] && [[ "$after" =~ [[:space:]] ]]; then
                            left_ref="${expr:0:$i}"
                            right_ref="${expr:$((i+${#operator}))}"
                            return 0
                        fi
                    fi
                fi
                ;;
        esac
        ((i++))
    done
    
    return 1
}

# eval_comparison()
# Evaluates single comparison (field operator value)
# Args:
#   $1 - comparison string (e.g., "uid > 1500")
#   $2 - reference to fields associative array
# Returns:
#   0 if true, 1 if false
eval_comparison() {
    local comparison="$1"
    local -n fields_ref=$2
    
    # Parse comparison: field operator value
    local field operator value
    
    # Try two-character operators first (>=, <=, !=, NOT LIKE)
    if [[ "$comparison" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+(NOT[[:space:]]+LIKE|>=|<=|!=)[[:space:]]+(.+)$ ]]; then
        field="${BASH_REMATCH[1]}"
        operator="${BASH_REMATCH[2]}"
        value="${BASH_REMATCH[3]}"
    # Then single-character operators (=, >, <, LIKE)
    elif [[ "$comparison" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+(LIKE|=|>|<)[[:space:]]+(.+)$ ]]; then
        field="${BASH_REMATCH[1]}"
        operator="${BASH_REMATCH[2]}"
        value="${BASH_REMATCH[3]}"
    else
        # Invalid comparison format
        return 1
    fi
    
    # Remove quotes from value if present
    value=$(echo "$value" | sed "s/^['\"]//;s/['\"]$//")
    
    # Get field value (case-insensitive field name)
    local field_value=""
    for key in "${!fields_ref[@]}"; do
        if [ "${key,,}" = "${field,,}" ]; then
            field_value="${fields_ref[$key]}"
            break
        fi
    done
    
    # Field not found = comparison fails
    [ -z "$field_value" ] && return 1
    
    # Evaluate based on operator (case-insensitive)
    case "${operator^^}" in
        "=")
            [ "${field_value,,}" = "${value,,}" ]
            ;;
        "!=")
            [ "${field_value,,}" != "${value,,}" ]
            ;;
        ">")
            compare_values "$field_value" "$value" "gt"
            ;;
        "<")
            compare_values "$field_value" "$value" "lt"
            ;;
        ">=")
            compare_values "$field_value" "$value" "ge"
            ;;
        "<=")
            compare_values "$field_value" "$value" "le"
            ;;
        "LIKE")
            match_pattern "${field_value,,}" "${value,,}"
            ;;
        "NOT LIKE")
            match_pattern "${field_value,,}" "${value,,}"
            [ $? -eq 0 ] && return 1 || return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# compare_values()
# Compares two values (numeric or string)
# Args:
#   $1 - left value
#   $2 - right value
#   $3 - comparison type (gt, lt, ge, le)
# Returns:
#   0 if true, 1 if false
compare_values() {
    local left="$1"
    local right="$2"
    local comp_type="$3"
    
    # Convert sizes to bytes if applicable
    left=$(convert_to_bytes "$left")
    right=$(convert_to_bytes "$right")
    
    # Convert time units to days if applicable
    left=$(convert_to_days "$left")
    right=$(convert_to_days "$right")
    
    # Try numeric comparison
    if [[ "$left" =~ ^[0-9]+$ ]] && [[ "$right" =~ ^[0-9]+$ ]]; then
        case "$comp_type" in
            gt) [ "$left" -gt "$right" ] ;;
            lt) [ "$left" -lt "$right" ] ;;
            ge) [ "$left" -ge "$right" ] ;;
            le) [ "$left" -le "$right" ] ;;
        esac
        return $?
    fi
    
    # Fall back to string comparison
    case "$comp_type" in
        gt) [[ "$left" > "$right" ]] ;;
        lt) [[ "$left" < "$right" ]] ;;
        ge) [[ "$left" > "$right" || "$left" = "$right" ]] ;;
        le) [[ "$left" < "$right" || "$left" = "$right" ]] ;;
    esac
}

# convert_to_bytes()
# Converts size string to bytes (100MB -> 104857600)
# Args:
#   $1 - size string
# Returns:
#   Size in bytes, or original string if not a size
convert_to_bytes() {
    local input="$1"
    
    # Check if it's a size string (ends with KB, MB, GB, TB)
    if [[ "$input" =~ ^([0-9]+)(KB|MB|GB|TB)$ ]]; then
        local number="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        
        case "$unit" in
            KB) echo $((number * 1024)) ;;
            MB) echo $((number * 1024 * 1024)) ;;
            GB) echo $((number * 1024 * 1024 * 1024)) ;;
            TB) echo $((number * 1024 * 1024 * 1024 * 1024)) ;;
        esac
    else
        echo "$input"
    fi
}

# convert_to_days()
# Converts time string to days (2w -> 14, 30d -> 30)
# Args:
#   $1 - time string
# Returns:
#   Time in days, or original string if not a time
convert_to_days() {
    local input="$1"
    
    # Check if it's a time string (ends with d, w, m, y)
    if [[ "$input" =~ ^([0-9]+)([dwmy])$ ]]; then
        local number="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        
        case "$unit" in
            d) echo "$number" ;;
            w) echo $((number * 7)) ;;
            m) echo $((number * 30)) ;;
            y) echo $((number * 365)) ;;
        esac
    else
        echo "$input"
    fi
}

# match_pattern()
# Matches value against pattern with wildcards
# Args:
#   $1 - value to match
#   $2 - pattern (with * and ? wildcards)
# Returns:
#   0 if matches, 1 if not
match_pattern() {
    local value="$1"
    local pattern="$2"
    
    # Convert SQL LIKE wildcards to bash glob
    # * -> .* (any characters)
    # ? -> . (single character)
    pattern=$(echo "$pattern" | sed 's/\*/\.\*/g' | sed 's/?/\./g')
    
    # Match with regex
    [[ "$value" =~ ^${pattern}$ ]]
}

# validate_expression()
# Validates expression syntax without evaluating
# Args:
#   $1 - expression string
# Returns:
#   0 if valid, 1 if invalid, prints error message
validate_expression() {
    local expr="$1"
    
    # Check balanced parentheses
    local paren_count=0
    local i=0
    while [ $i -lt ${#expr} ]; do
        case "${expr:$i:1}" in
            '(') ((paren_count++)) ;;
            ')') ((paren_count--)) ;;
        esac
        
        if [ $paren_count -lt 0 ]; then
            echo "ERROR: Unbalanced parentheses (too many closing)"
            return 1
        fi
        ((i++))
    done
    
    if [ $paren_count -ne 0 ]; then
        echo "ERROR: Unbalanced parentheses (unclosed)"
        return 1
    fi
    
    # Check for valid operators (basic check)
    # More comprehensive validation could be added
    
    return 0
}

# test_expression_parser()
# Unit tests for expression parser
test_expression_parser() {
    echo "Testing Expression Parser..."
    echo ""
    
    # Test data
    local test_data=(
        "uid=1501"
        "status=active"
        "home_size=104857600"  # 100MB in bytes
        "last_login=25"         # days
        "username=alice"
        "shell=/bin/bash"
    )
    
    # Test cases: expression, expected_result
    local tests=(
        "uid > 1500|0"
        "uid = 1501|0"
        "status = active|0"
        "status != locked|0"
        "home_size > 50MB|0"
        "home_size < 200MB|0"
        "last_login < 30d|0"
        "username LIKE 'a*'|0"
        "username NOT LIKE 'b*'|0"
        "uid > 1500 AND status = active|0"
        "uid > 2000 OR status = active|0"
        "NOT status = locked|0"
        "(uid > 1500 AND status = active) OR username = bob|0"
        "uid > 2000|1"
        "status = locked|1"
    )
    
    local passed=0
    local failed=0
    
    for test in "${tests[@]}"; do
        local expr="${test%|*}"
        local expected="${test##*|}"
        
        parse_where_expression "$expr" "${test_data[@]}"
        local result=$?
        
        if [ "$result" -eq "$expected" ]; then
            echo "✓ PASS: $expr"
            ((passed++))
        else
            echo "✗ FAIL: $expr (expected $expected, got $result)"
            ((failed++))
        fi
    done
    
    echo ""
    echo "Results: $passed passed, $failed failed"
    
    [ $failed -eq 0 ]
}

# If run directly, execute tests
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    test_expression_parser
fi