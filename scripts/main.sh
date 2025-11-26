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

    if [ "$(user_exists "$username")" = "yes" ]; then
        echo "User already exists"
        return 1
    fi

    useradd -m "$username"
    echo "User created"
}

main() {
    command=""
    username=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --add)
                command="add"
                ;;
            --name)
                username="$2"
                shift
                ;;
            *)
                echo "Unknown option $1"
                ;;
        esac
        shift
    done

    if [ "$command" = "add" ]; then
        add_user "$username"
        return
    fi

    echo "Usage: $0 --add --name <username>"
}

main "$@"
