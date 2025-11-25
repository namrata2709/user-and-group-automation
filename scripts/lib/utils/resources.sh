#!/usr/bin/env bash
get_home_size() {
    local home
    home=$(eval echo ~"$1")
    if [ -d "$home" ]; then
        du -sh "$home" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}
get_home_size_bytes() {
    local home
    home=$(eval echo ~"$1")
    if [ -d "$home" ]; then
        du -sb "$home" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}
count_user_processes() {
    ps -u "$1" 2>/dev/null | wc -l
}
get_user_processes() {
    ps -u "$1" -o pid,comm --no-headers 2>/dev/null
}
count_user_cron_jobs() {
    sudo crontab -u "$1" -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l
}
get_user_crontab() {
    sudo crontab -u "$1" -l 2>/dev/null || echo ""
}
get_user_mail_size() {
    local mail_file="/var/mail/$1"
    [ -f "$mail_file" ] && du -h "$mail_file" | cut -f1 || echo "0"
}
find_processes_by_group() {
    ps -eo pid,user,group,comm 2>/dev/null | grep " $1 " | grep -v "grep"
}