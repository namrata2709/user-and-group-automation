#!/usr/bin/env bash
find_files_by_group() {
    sudo find / -group "$1" -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | head -100
}
find_user_files_outside_home() {
    local username="$1"
    local home
    home=$(eval echo ~"$username")
    sudo find / -user "$username" -not -path "$home/*" -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | head -20
}