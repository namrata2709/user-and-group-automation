source ./lib/utils/validation.sh
source ./lib/user_helper.sh
source ./lib/user_add.sh
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

}

main "$@"
