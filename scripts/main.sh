user_exists() {
    local username="$1"

    if id "$username" >/dev/null 2>&1; then
        echo "yes"
        return 0
    fi

    echo "no"
    return 1
}

add_user() {
    local username="$1"
    local password="$2"

    if [ "$(user_exists "$username")" = "yes" ]; then
        echo "User already exists"
        return 1
    fi

    useradd -m "$username"
    echo "$username:$password" | chpasswd

    echo "User created"
}
