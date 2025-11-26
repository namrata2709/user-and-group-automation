#!/usr/bin/env bash
# ================================================
# JSON Helper Module
# ================================================

# Escape string for JSON
json_escape() {
    local string="$1"
    string="${string//\\/\\\\}"
    string="${string//\"/\\\"}"
    string="${string//$'\t'/\\t}"
    string="${string//$'\n'/\\n}"
    string="${string//$'\r'/\\r}"
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