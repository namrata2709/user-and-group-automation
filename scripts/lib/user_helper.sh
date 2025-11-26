user_exists() {
    local username="$1"

    if [ "$(user_exists "$username")" = "yes" ]; then
        return 1
    fi

    echo "no"
    return 1
}