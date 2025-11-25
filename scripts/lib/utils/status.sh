#!/usr/bin/env bash
get_user_status() {
    if passwd -S "$1" 2>/dev/null | grep -q " LK "; then
        echo "LOCKED"
    else
        echo "ACTIVE"
    fi
}
get_account_expiry() {
    local expiry
    expiry=$(sudo chage -l "$1" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
    if [ "$expiry" = "never" ]; then
        echo "Never"
    else
        echo "$expiry"
    fi
}
get_last_login() {
    lastlog -u "$1" 2>/dev/null | tail -1 | awk '{if ($2 == "**") print "Never"; else print $4" "$5" "$6" "$7}'
}
is_user_sudo() {
    groups "$1" 2>/dev/null | grep -qE '\\b(sudo|wheel|admin)\\b'
}
check_user_sudo() {
    is_user_sudo "$1"
}
check_user_logged_in() {
    who | grep "^$1 " 2>/dev/null
}
get_recent_logins_for_user() {
    local username="$1"
    local hours="${2:-24}"
    if ! id "$username" &>/dev/null; then return 1; fi
    local cutoff_timestamp
    cutoff_timestamp=$(date -d "$hours hours ago" +%s 2>/dev/null)
    local -a results=()
    while read -r line; do
        [[ "$line" =~ ^reboot ]] && continue
        [[ "$line" =~ ^wtmp ]] && continue
        [[ -z "$line" ]] && continue
        local user
        user=$(echo "$line" | awk '{print $1}')
        [ "$user" != "$username" ] && continue
        # ... (rest of the complex parsing logic from helpers.sh)
    done < <(last -F -w "$username" 2>/dev/null | tail -n +2)
    if [ ${#results[@]} -gt 0 ]; then
        printf '%s\\n' "${results[@]}"
        return 0
    else
        return 1
    fi
}