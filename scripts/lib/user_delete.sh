#!/usr/bin/env bash
# ================================================
# User Delete Module
# Version: 1.0.1
# ================================================

delete_check_user() {
    local username="$1"
    
    echo "=========================================="
    echo "Pre-Deletion Check: $username"
    echo "=========================================="
    echo ""
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    local uid=$(id -u "$username")
    local gid=$(id -g "$username")
    local groups_list=$(groups "$username" 2>/dev/null | cut -d: -f2-)
    local home=$(eval echo ~"$username")
    local shell=$(getent passwd "$username" | cut -d: -f7)
    local gecos=$(getent passwd "$username" | cut -d: -f5)
    
    echo "USER INFORMATION:"
    echo "  Username:        $username"
    echo "  UID:             $uid"
    echo "  Primary Group:   $(id -gn "$username") ($gid)"
    echo "  Secondary Groups:$groups_list"
    [ -n "$gecos" ] && echo "  Comment:         $gecos"
    echo "  Home:            $home"
    echo "  Shell:           $shell"
    
    if passwd -S "$username" 2>/dev/null | grep -q " LK "; then
        echo "  Status:          LOCKED ${ICON_LOCK}"
    else
        echo "  Status:          ACTIVE"
    fi
    echo ""
    
    local warnings=0
    
    echo "LOGIN STATUS:"
    local logged_in=$(check_user_logged_in "$username")
    if [ -n "$logged_in" ]; then
        echo "  ${ICON_WARNING} Currently logged in:"
        echo "$logged_in" | while read line; do
            echo "    - $line"
        done
        ((warnings++))
    else
        echo "  ${ICON_SUCCESS} Not logged in"
    fi
    echo ""
    
    echo "ACTIVE PROCESSES:"
    local processes=$(get_user_processes "$username")
    if [ -n "$processes" ]; then
        local proc_count=$(echo "$processes" | wc -l)
        echo "  ${ICON_WARNING} $proc_count process(es) running:"
        echo "$processes" | head -10 | while read pid comm; do
            echo "    PID $pid: $comm"
        done
        [ "$proc_count" -gt 10 ] && echo "    ... and $((proc_count - 10)) more"
        ((warnings++))
    else
        echo "  ${ICON_SUCCESS} No active processes"
    fi
    echo ""
    
    echo "CRON JOBS:"
    local crontab=$(get_user_crontab "$username")
    if [ -n "$crontab" ]; then
        local cron_count=$(echo "$crontab" | grep -v "^#" | grep -v "^$" | wc -l)
        echo "  ${ICON_WARNING} $cron_count cron job(s):"
        echo "$crontab" | grep -v "^#" | grep -v "^$" | head -5 | while read line; do
            echo "    $line"
        done
        ((warnings++))
    else
        echo "  ${ICON_SUCCESS} No cron jobs"
    fi
    echo ""
    
    echo "MAIL:"
    local mail_size=$(get_user_mail_size "$username")
    if [ "$mail_size" != "0" ]; then
        echo "  ${ICON_INFO} Mail exists: $mail_size"
        echo "     Location: /var/mail/$username"
    else
        echo "  ${ICON_SUCCESS} No mail"
    fi
    echo ""
    
    echo "HOME DIRECTORY:"
    if [ -d "$home" ]; then
        local home_size=$(get_home_size "$username")
        local file_count=$(find "$home" -type f 2>/dev/null | wc -l)
        echo "  ${ICON_INFO} $home"
        echo "     Size:  $home_size"
        echo "     Files: $file_count"
    else
        echo "  ${ICON_SUCCESS} No home directory"
    fi
    echo ""
    
    echo "FILES OUTSIDE HOME:"
    local outside_files=$(find_user_files_outside_home "$username")
    if [ -n "$outside_files" ]; then
        local outside_count=$(echo "$outside_files" | wc -l)
        echo "  ${ICON_WARNING} $outside_count file(s) found:"
        echo "$outside_files" | head -10 | while read file; do
            echo "    $file"
        done
        [ "$outside_count" -gt 10 ] && echo "    ... and more (showing first 10)"
        ((warnings++))
    else
        echo "  ${ICON_SUCCESS} No files outside home"
    fi
    echo ""
    
    echo "SUDO ACCESS:"
    if check_user_sudo "$username"; then
        echo "  ${ICON_WARNING} YES - User has sudo/admin privileges"
        ((warnings++))
    else
        echo "  ${ICON_SUCCESS} No sudo access"
    fi
    echo ""
    
    echo "=========================================="
    if [ $warnings -gt 0 ]; then
        echo "${ICON_WARNING} $warnings WARNING(S) FOUND"
        echo ""
        echo "RECOMMENDATIONS:"
        echo "  1. Lock user first: ./user.sh --lock user --name $username"
        echo "  2. Force logout if needed"
        echo "  3. Backup data before deletion"
        echo "  4. Use interactive mode for safe deletion"
        echo ""
        echo "NEXT STEPS:"
        echo "  Interactive: ./user.sh --delete user --name $username"
        echo "  Auto-backup: ./user.sh --delete user --name $username --backup \\"
        echo "               --backup-dir /var/backups/users --force-logout"
    else
        echo "${ICON_SUCCESS} Safe to delete (no warnings)"
        echo ""
        echo "NEXT STEPS:"
        echo "  Delete: ./user.sh --delete user --name $username"
    fi
    echo "=========================================="
    
    log_action "delete_check" "$username" "COMPLETE" "$warnings warnings found"
}

create_user_backup() {
    local username="$1"
    local backup_base="$2"
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_dir="$backup_base/${username}_${timestamp}"
    
    echo "${ICON_BACKUP} Creating backup: $backup_dir"
    sudo mkdir -p "$backup_dir"
    
    {
        echo "User Deletion Backup"
        echo "===================="
        echo "Username: $username"
        echo "UID: $(id -u "$username")"
        echo "GID: $(id -g "$username")"
        echo "Groups: $(groups "$username")"
        echo "Home: $(eval echo ~"$username")"
        echo "Shell: $(getent passwd "$username" | cut -d: -f7)"
        echo "Backup Date: $(date)"
        echo "Deleted By: $USER"
    } | sudo tee "$backup_dir/metadata.txt" >/dev/null
    
    local home=$(eval echo ~"$username")
    if [ -d "$home" ]; then
        echo "  Backing up home directory..."
        sudo tar -czf "$backup_dir/home_backup.tar.gz" -C "$(dirname "$home")" "$(basename "$home")" 2>/dev/null
        echo "  ${ICON_SUCCESS} Home backed up"
    fi
    
    local crontab=$(get_user_crontab "$username")
    if [ -n "$crontab" ]; then
        echo "$crontab" | sudo tee "$backup_dir/crontab.txt" >/dev/null
        echo "  ${ICON_SUCCESS} Crontab backed up"
    fi
    
    if [ -f "/var/mail/$username" ]; then
        sudo tar -czf "$backup_dir/mail.tar.gz" "/var/mail/$username" 2>/dev/null
        echo "  ${ICON_SUCCESS} Mail backed up"
    fi
    
    sudo find / -user "$username" -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | \
        sudo tee "$backup_dir/file_list.txt" >/dev/null
    
    echo "${ICON_SUCCESS} Backup complete: $backup_dir"
    echo "$backup_dir"
}

delete_user_interactive() {
    local username="$1"
    
    echo "=========================================="
    echo "Interactive User Deletion: $username"
    echo "=========================================="
    echo ""
    
    local logged_in=$(check_user_logged_in "$username")
    local processes=$(get_user_processes "$username")
    local proc_count=0
    [ -n "$processes" ] && proc_count=$(echo "$processes" | wc -l)
    
    echo "Summary:"
    echo "  User: $username"
    [ -n "$logged_in" ] && echo "  Status: Currently logged in ${ICON_WARNING}" || echo "  Status: Not logged in"
    echo "  Processes: $proc_count"
    echo ""
    
    if [ -n "$logged_in" ]; then
        echo "Step 1: User is currently logged in"
        read -p "Force logout? [y/n]: " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo pkill -u "$username"
            echo "  ${ICON_SUCCESS} User logged out"
        fi
        echo ""
    fi
    
    if [ "$proc_count" -gt 0 ]; then
        echo "Step 2: User has $proc_count active process(es)"
        echo "  [g] Graceful (SIGTERM)"
        echo "  [f] Force kill (SIGKILL)"
        echo "  [s] Skip"
        read -p "Choice: " response
        case "$response" in
            [Gg])
                sudo pkill -TERM -u "$username"
                sleep 2
                echo "  ${ICON_SUCCESS} Processes terminated (graceful)"
                ;;
            [Ff])
                sudo pkill -KILL -u "$username"
                echo "  ${ICON_SUCCESS} Processes killed (force)"
                ;;
            *)
                echo "  Skipped"
                ;;
        esac
        echo ""
    fi
    
    echo "Step 3: Backup user data?"
    read -p "Enter backup directory path (or 'skip'): " backup_input
    
    local backup_created=""
    if [ "$backup_input" != "skip" ] && [ -n "$backup_input" ]; then
        if [ ! -d "$backup_input" ]; then
            sudo mkdir -p "$backup_input"
        fi
        backup_created=$(create_user_backup "$username" "$backup_input")
        echo ""
    fi
    
    echo "Step 4: Home directory"
    echo "  [d] Delete home directory"
    echo "  [k] Keep home directory"
    read -p "Choice [d/k]: " response
    local delete_home=true
    [[ "$response" =~ ^[Kk]$ ]] && delete_home=false
    echo ""
    
    echo "Step 5: Final confirmation"
    echo "  User: $username"
    echo "  Delete home: $delete_home"
    [ -n "$backup_created" ] && echo "  Backup: $backup_created"
    echo ""
    read -p "Proceed with deletion? [yes/no]: " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "${ICON_ERROR} Deletion cancelled"
        return 1
    fi
    
    echo ""
    echo "${ICON_DELETE} Deleting user: $username"
    
    if $delete_home; then
        sudo userdel -r "$username" 2>/dev/null
    else
        sudo userdel "$username" 2>/dev/null
    fi
    
    echo "${ICON_SUCCESS} User deleted successfully"
    [ -n "$backup_created" ] && echo "${ICON_BACKUP} Backup saved: $backup_created"
    
    log_action "delete_user_interactive" "$username" "SUCCESS" "Backup: $backup_created"
}

delete_user_auto() {
    local username="$1"
    
    echo "=========================================="
    echo "Auto-Delete with Backup: $username"
    echo "=========================================="
    echo ""
    
    if [ -z "$BACKUP_DIR" ]; then
        echo "${ICON_ERROR} Error: --backup-dir required for auto-backup mode"
        echo "Usage: --delete user --name $username --backup --backup-dir /path"
        return 1
    fi
    
    if $FORCE_LOGOUT; then
        echo "${ICON_LOCK} Forcing logout..."
        sudo pkill -u "$username" 2>/dev/null || true
    fi
    
    if $KILL_PROCESSES; then
        echo "${ICON_DELETE} Terminating processes..."
        sudo pkill -KILL -u "$username" 2>/dev/null || true
    fi
    
    local backup_created=$(create_user_backup "$username" "$BACKUP_DIR")
    echo ""
    
    echo "${ICON_DELETE} Deleting user: $username"
    if $KEEP_HOME; then
        sudo userdel "$username" 2>/dev/null
        echo "${ICON_SUCCESS} User deleted (home directory preserved)"
    else
        sudo userdel -r "$username" 2>/dev/null
        echo "${ICON_SUCCESS} User and home directory deleted"
    fi
    
    echo ""
    echo "=========================================="
    echo "${ICON_SUCCESS} Deletion complete"
    echo "${ICON_BACKUP} Backup: $backup_created"
    echo "=========================================="
    
    log_action "delete_user_auto" "$username" "SUCCESS" "Backup: $backup_created"
}

delete_user_force() {
    local username="$1"
    
    echo "=========================================="
    echo "${ICON_WARNING} FORCE DELETE (No Backup): $username"
    echo "=========================================="
    echo ""
    
    echo "WARNING: This will delete user without backup!"
    read -p "Type username to confirm: " confirm
    
    if [ "$confirm" != "$username" ]; then
        echo "${ICON_ERROR} Confirmation failed. Deletion cancelled."
        return 1
    fi
    
    echo ""
    echo "${ICON_DELETE} Force deleting user: $username"
    
    sudo pkill -KILL -u "$username" 2>/dev/null || true
    sudo userdel -r "$username" 2>/dev/null
    
    echo "${ICON_SUCCESS} User forcefully deleted (no backup created)"
    
    log_action "delete_user_force" "$username" "SUCCESS" "Force delete, no backup"
}

delete_user() {
    local username="$1"
    
    if ! id "$username" &>/dev/null; then
        echo "${ICON_ERROR} User '$username' does not exist"
        return 1
    fi
    
    case "$DELETE_MODE" in
        check)
            delete_check_user "$username"
            ;;
        interactive)
            delete_user_interactive "$username"
            ;;
        auto)
            delete_user_auto "$username"
            ;;
        force)
            delete_user_force "$username"
            ;;
        *)
            echo "${ICON_ERROR} Invalid delete mode: $DELETE_MODE"
            return 1
            ;;
    esac
}

delete_users_batch() {
    local user_file="$1"
    
    if [[ ! -f "$user_file" ]]; then
        echo "${ICON_ERROR} User file not found: $user_file"
        exit 1
    fi
    
    echo "${ICON_WARNING} Batch delete mode (basic)"
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line=$(echo "$line" | sed 's/#.*$//' | xargs)
        [ -z "$line" ] && continue
        username=$(echo "$line" | cut -d':' -f1)
        if id "$username" &>/dev/null; then
            sudo userdel -r "$username" 2>/dev/null
            echo "${ICON_SUCCESS} Deleted: $username"
        fi
    done < "$user_file"
}