#!/usr/bin/env bash
# ===============================================
# Audit Report Module
# Version: 2.0.0
# ===============================================

# =============================================================================
# PRIVATE: _generate_report_header
# =============================================================================
_generate_report_header() {
    local title="$1"
    print_banner "$title"
    echo -e "${C_GRAY}Generated: $(date '+%Y-%m-%d %H:%M:%S')${C_RESET}"
    echo ""
}

# =============================================================================
# PRIVATE: _check_sudo_users
# =============================================================================
_check_sudo_users() {
    print_section_header "1. Users with Sudo Access"
    local sudo_users=$(get_sudo_users)
    if [ -n "$sudo_users" ]; then
        while IFS= read -r user; do
            local status=$(get_user_status "$user")
            local last_login=$(get_last_login_formatted "$user")
            print_warning "  $user (Status: $status, Last Login: $last_login)"
        done <<< "$sudo_users"
    else
        print_success "  No users found with sudo access."
    fi
    echo ""
}

# =============================================================================
# PRIVATE: _check_locked_accounts
# =============================================================================
_check_locked_accounts() {
    print_section_header "2. Locked Accounts"
    local locked_users=$(get_locked_users)
    if [ -n "$locked_users" ]; then
        while IFS= read -r user; do
            print_info "  $user"
        done <<< "$locked_users"
    else
        print_success "  No locked accounts found."
    fi
    echo ""
}

# =============================================================================
# PRIVATE: _check_password_expiry
# =============================================================================
_check_password_expiry() {
    print_section_header "3. Password Expiration Status"
    local expired_users=$(get_users_with_expired_passwords)
    local no_expiry_users=$(get_users_without_password_expiry)

    if [ -n "$expired_users" ]; then
        print_warning "  Expired Passwords:"
        while IFS= read -r user; do
            local expiry_date=$(get_password_expiry_date "$user")
            echo "    - $user (Expired on: $expiry_date)"
        done <<< "$expired_users"
    else
        print_success "  No users with expired passwords."
    fi

    if [ -n "$no_expiry_users" ]; then
        print_warning "  No Password Expiry:"
        while IFS= read -r user; do
            echo "    - $user"
        done <<< "$no_expiry_users"
    else
        print_success "  All users have password expiry set."
    fi
    echo ""
}

# =============================================================================
# PRIVATE: _check_inactive_accounts
# =============================================================================
_check_inactive_accounts() {
    local days_threshold="${1:-90}"
    print_section_header "4. Inactive Accounts (No login in > $days_threshold days)"
    local inactive_users=$(get_inactive_users "$days_threshold")
    
    if [ -n "$inactive_users" ]; then
        while IFS= read -r user; do
            local last_login=$(get_last_login_formatted "$user")
            print_warning "  $user (Last Login: $last_login)"
        done <<< "$inactive_users"
    else
        print_success "  No inactive accounts found."
    fi
    echo ""
}

# =============================================================================
# PRIVATE: _check_storage_usage
# =============================================================================
_check_storage_usage() {
    print_section_header "5. Home Directory Storage Usage"
    local top_users=$(get_top_storage_users 10)
    if [ -n "$top_users" ]; then
        print_info "  Top 10 Largest Home Directories:"
        while IFS= read -r line; do
            local size=$(echo "$line" | awk '{print $1}')
            local user=$(echo "$line" | awk '{print $2}')
            echo "    - $user: $size"
        done <<< "$top_users"
    else
        print_success "  Could not determine storage usage."
    fi
    echo ""
}

# =============================================================================
# PUBLIC: report_security
# =============================================================================
report_security() {
    _generate_report_header "Security Audit Report"
    _check_sudo_users
    _check_locked_accounts
    _check_password_expiry
    log_action "report_security" "system" "SUCCESS" "Generated security audit report."
}

# =============================================================================
# PUBLIC: report_compliance
# =============================================================================
report_compliance() {
    _generate_report_header "Compliance Report"
    _check_password_expiry
    _check_inactive_accounts 90
    log_action "report_compliance" "system" "SUCCESS" "Generated compliance report."
}

# =============================================================================
# PUBLIC: report_activity
# =============================================================================
report_activity() {
    local days="${1:-30}"
    _generate_report_header "User Activity Report (Last $days days)"
    
    print_section_header "1. Login Frequency"
    local login_counts=$(get_login_counts "$days")
    if [ -n "$login_counts" ]; then
        print_info "  Top 10 most active users:"
        echo "$login_counts" | head -n 10 | while IFS= read -r line; do
            echo "    - $line"
        done
    else
        print_success "  No login activity recorded in the last $days days."
    fi
    echo ""

    _check_inactive_accounts "$days"
    
    log_action "report_activity" "system" "SUCCESS" "Generated activity report for last $days days."
}

# =============================================================================
# PUBLIC: report_storage
# =============================================================================
report_storage() {
    _generate_report_header "Storage Report"
    _check_storage_usage
    
    print_section_header "2. Orphaned Files in /home"
    local orphaned_files=$(find_orphaned_files "/home")
    if [ -n "$orphaned_files" ]; then
        print_warning "  Found orphaned files. First 10:"
        echo "$orphaned_files" | head -n 10 | while IFS= read -r file; do
            echo "    - $file"
        done
    else
        print_success "  No orphaned files found in /home."
    fi
    
    log_action "report_storage" "system" "SUCCESS" "Generated storage report."
}