user_exists() {
    local username="$1"
    
    if id "$username" >/dev/null 2>&1; then
        echo "yes"
        return 0
    fi
    
    echo "no"
    return 1
}