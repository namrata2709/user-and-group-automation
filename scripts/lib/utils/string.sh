#!/usr/bin/env bash
trim() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}
join_array() {
    local delimiter="$1"
    shift
    local result=""
    local first=true
    for item in "$@"; do
        if [ "$first" = true ]; then
            result="$item"
            first=false
        else
            result="$result$delimiter$item"
        fi
    done
    echo "$result"
}