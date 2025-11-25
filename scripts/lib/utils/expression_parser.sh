#!/usr/bin/env bash

# =================================================================================================
#
# Expression Parser Module
#
# Description:
#   This module provides a powerful and flexible way to parse and evaluate conditional
#   expressions, primarily for the '--where' clause in the '--view' command. It allows users
#   to construct complex queries using logical operators (AND, OR, NOT), comparison
#   operators (=, !=, >, <, >=, <=), and pattern matching (LIKE, MATCHES).
#
#   The parser is designed to handle nested expressions with parentheses and can correctly
#   evaluate different data types, including strings, numbers, dates, and file sizes.
#
# Key Features:
#   - Logical Operators: Supports AND, OR, and NOT for combining conditions.
#   - Parentheses: Correctly handles nested expressions for precedence.
#   - Rich Comparisons: Evaluates standard comparisons, plus LIKE for wildcard matching
#     and MATCHES for regex.
#   - Type Awareness: Automatically handles comparisons for numbers, dates (by converting
#     to timestamps), and file sizes (by converting to bytes).
#
# Example Usage (within the context of the main script):
#   --where "status = 'active' AND (home_size > '1GB' OR last_login < '30d')"
#
# =================================================================================================

# =================================================================================================
# FUNCTION: parse_where_expression
# DESCRIPTION:
#   The main entry point for parsing a 'where' expression. It takes the expression string
#   and an array of data (key-value pairs) and initiates the evaluation.
#
# PARAMETERS:
#   $1 - expression: The logical expression string to evaluate.
#   $@ - data: An array of key-value pairs representing the data for a single record
#        (e.g., "username=jdoe" "uid=1001").
#
# RETURNS:
#   0 if the expression evaluates to true, 1 otherwise.
# =================================================================================================
parse_where_expression() {
    local expression="$1"
    shift
    local data=("$@")

    [ -z "$expression" ] && return 0

    # Convert the data array into an associative array for easy lookups.
    declare -A fields
    for item in "${data[@]}"; do
        local key="${item%%=*}"
        local value="${item#*=}"
        fields[$key]="$value"
    done

    eval_expression "$expression" fields
}

# =================================================================================================
# FUNCTION: eval_expression
# DESCRIPTION:
#   Recursively evaluates a logical expression. It identifies the top-level logical operator
#   (OR, AND, NOT) and splits the expression to evaluate each part, respecting operator
#   precedence (OR is evaluated before AND).
#
# PARAMETERS:
#   $1 - expr: The expression or sub-expression to evaluate.
#   $2 - fields_ref: A nameref to the associative array of data fields.
#
# RETURNS:
#   The exit code of the evaluated condition (0 for true, 1 for false).
# =================================================================================================
eval_expression() {
    local expr="$1"
    local -n fields_ref=$2

    expr=$(echo "$expr" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Handle parenthesized expressions by recursively calling this function.
    if [[ "$expr" =~ ^\((.*)\)$ ]]; then
        expr="${expr:1:-1}"
        eval_expression "$expr" fields_ref
        return $?
    fi

    # Split by 'OR' first, as it has lower precedence.
    if contains_top_level_operator "$expr" "OR"; then
        local left right
        split_by_operator "$expr" "OR" left right
        eval_expression "$left" fields_ref || eval_expression "$right" fields_ref
        return $?
    fi

    # Then split by 'AND'.
    if contains_top_level_operator "$expr" "AND"; then
        local left right
        split_by_operator "$expr" "AND" left right
        eval_expression "$left" fields_ref && eval_expression "$right" fields_ref
        return $?
    fi

    # Handle 'NOT' operator.
    if [[ "$expr" =~ ^NOT[[:space:]]+ ]]; then
        local inner="${expr#NOT }"
        inner=$(echo "$inner" | sed 's/^[[:space:]]*//')
        ! eval_expression "$inner" fields_ref
        return $?
    fi

    # If no logical operators are found, evaluate it as a simple comparison.
    eval_comparison "$expr" fields_ref
}

# =================================================================================================
# FUNCTION: contains_top_level_operator
# DESCRIPTION:
#   Checks if an expression contains a specific logical operator (AND, OR) at the top level
#   (i.e., not inside parentheses).
#
# PARAMETERS:
#   $1 - expr: The expression string.
#   $2 - operator: The operator to search for ("AND" or "OR").
#
# RETURNS:
#   0 if the operator is found at the top level, 1 otherwise.
# =================================================================================================
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
                    local substr="${expr:$i:${#operator}}"
                    if [ "${substr^^}" = "$operator" ]; then
                        # Ensure it's a whole word, surrounded by spaces.
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

# =================================================================================================
# FUNCTION: split_by_operator
# DESCRIPTION:
#   Splits an expression into two parts (left and right) based on the first occurrence of a
#   top-level logical operator.
#
# PARAMETERS:
#   $1 - expr: The expression string.
#   $2 - operator: The operator to split by.
#   $3 - left_ref: A nameref to store the left part of the expression.
#   $4 - right_ref: A nameref to store the right part of the expression.
#
# RETURNS:
#   0 on successful split, 1 otherwise.
# =================================================================================================
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

# =================================================================================================
# FUNCTION: eval_comparison
# DESCRIPTION:
#   Evaluates a single comparison expression (e.g., "uid > 1000"). It parses the field,
#   operator, and value, then performs the appropriate comparison.
#
# PARAMETERS:
#   $1 - comparison: The comparison string.
#   $2 - fields_ref: A nameref to the associative array of data fields.
#
# RETURNS:
#   The exit code of the comparison (0 for true, 1 for false).
# =================================================================================================
eval_comparison() {
    local comparison="$1"
    local -n fields_ref=$2
    local field operator value

    # Regex to parse "field operator value" structure.
    if [[ "$comparison" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+(NOT[[:space:]]+LIKE|NOT[[:space:]]+MATCHES|>=|<=|!=|MATCHES|LIKE|=|>|<)[[:space:]]+(.+)$ ]]; then
        field="${BASH_REMATCH[1]}"
        operator="${BASH_REMATCH[2]}"
        value="${BASH_REMATCH[3]}"
    else
        return 1 # Invalid comparison format.
    fi

    # Trim quotes from the value.
    value=$(echo "$value" | sed "s/^['\"]//;s/['\"]$//")

    # Find the actual value of the field from the data map (case-insensitive).
    local field_value=""
    for key in "${!fields_ref[@]}"; do
        if [ "${key,,}" = "${field,,}" ]; then
            field_value="${fields_ref[$key]}"
            break
        fi
    done

    [ -z "$field_value" ] && [ "$field_value" != "0" ] && return 1 # Field not found.

    case "${operator^^}" in
        "MATCHES")
            [[ "$field_value" =~ $value ]]
            ;;
        "NOT MATCHES")
            ! [[ "$field_value" =~ $value ]]
            ;;
        "LIKE")
            match_pattern "${field_value,,}" "${value,,}"
            ;;
        "NOT LIKE")
            ! match_pattern "${field_value,,}" "${value,,}"
            ;;
        ">"|"<"|">="|"<=")
            # Special handling for date/time fields.
            if [[ "$field" == *"date"* || "$field" == *"login"* || "$field" == *"expires"* ]]; then
                local field_ts=$(date -d "$field_value" +%s 2>/dev/null || echo 0)
                local value_ts=$(date -d "$value" +%s 2>/dev/null || echo 0)

                if [[ $field_ts -gt 0 && $value_ts -gt 0 ]]; then
                    case "${operator^^}" in
                        ">") [ "$field_ts" -gt "$value_ts" ] ;;
                        "<") [ "$field_ts" -lt "$value_ts" ] ;;
                        ">=") [ "$field_ts" -ge "$value_ts" ] ;;
                        "<=") [ "$field_ts" -le "$value_ts" ] ;;
                    esac
                    return $?
                fi
            fi
            compare_values "$field_value" "$value" "${operator,,}"
            ;;
        *)
            compare_values "$field_value" "$value" "${operator,,}"
            ;;
    esac
}

# =================================================================================================
# FUNCTION: compare_values
# DESCRIPTION:
#   Compares two values, attempting to treat them as numbers first, then as strings.
#   It also handles special unit conversions for file sizes and time durations.
#
# PARAMETERS:
#   $1 - left: The left-hand value.
#   $2 - right: The right-hand value.
#   $3 - comp_type: The comparison operator (e.g., 'gt', 'lt', '=', '!=').
# =================================================================================================
compare_values() {
    local left="$1"
    local right="$2"
    local comp_type="$3"

    # Convert file sizes (e.g., '1GB') to bytes and time durations (e.g., '30d') to days.
    left=$(convert_to_bytes "$left")
    right=$(convert_to_bytes "$right")
    left=$(convert_to_days "$left")
    right=$(convert_to_days "$right")

    # Perform a numeric comparison if both values are integers.
    if [[ "$left" =~ ^[0-9]+$ ]] && [[ "$right" =~ ^[0-9]+$ ]]; then
        case "$comp_type" in
            gt|">") [ "$left" -gt "$right" ] ;;
            lt|"<") [ "$left" -lt "$right" ] ;;
            ge|">=") [ "$left" -ge "$right" ] ;;
            le|"<=") [ "$left" -le "$right" ] ;;
            "="|"!=") [ "$left" "$comp_type" "$right" ] ;;
        esac
        return $?
    fi

    # Otherwise, perform a string comparison.
    case "$comp_type" in
        gt|">") [[ "$left" > "$right" ]] ;;
        lt|"<") [[ "$left" < "$right" ]] ;;
        ge|">=") [[ "$left" > "$right" || "$left" = "$right" ]] ;;
        le|"<=") [[ "$left" < "$right" || "$left" = "$right" ]] ;;
         "="|"!=") [ "$left" "$comp_type" "$right" ] ;;
    esac
}

# =================================================================================================
# FUNCTION: convert_to_bytes
# DESCRIPTION:
#   Converts a file size string (e.g., "512MB") into bytes.
# =================================================================================================
convert_to_bytes() {
    local input="$1"
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

# =================================================================================================
# FUNCTION: convert_to_days
# DESCRIPTION:
#   Converts a time duration string (e.g., "4w") into days.
# =================================================================================================
convert_to_days() {
    local input="$1"
    if [[ "$input" =~ ^([0-9]+)([dwmy])$ ]]; then
        local number="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        case "$unit" in
            d) echo "$number" ;;
            w) echo $((number * 7)) ;;
            m) echo $((number * 30)) ;; # Approximation
            y) echo $((number * 365)) ;; # Approximation
        esac
    else
        echo "$input"
    fi
}

# =================================================================================================
# FUNCTION: match_pattern
# DESCRIPTION:
#   Performs a wildcard pattern match (SQL LIKE style). It converts '*' to '.*' and '?' to '.'
#   for use in a regex comparison.
# =================================================================================================
match_pattern() {
    local value="$1"
    local pattern="$2"
    pattern=$(echo "$pattern" | sed 's/\*/.*/g' | sed 's/?/./g')
    [[ "$value" =~ ^${pattern}$ ]]
}

# =================================================================================================
# FUNCTION: validate_expression
# DESCRIPTION:
#   A simple validator to check for balanced parentheses in an expression.
# =================================================================================================
validate_expression() {
    local expr="$1"
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
    return 0
}

# --- Self-testing ---
# If the script is run directly, it executes a test suite.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    test_expression_parser
fi