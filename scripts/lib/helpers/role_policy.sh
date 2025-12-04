#!/bin/bash
apply_role_defaults() {
    local role="$1"
    
    case "$role" in
        admin)
            user_shell="$SHELL_ROLE_ADMIN"
            account_expiry_days="$ACCOUNT_EXPIRY_ADMIN"
            sudo_access="${sudo_access:-allow}" 
            echo "INFO: Applied 'admin' role defaults"
            return 0
            ;;
        developer)
            user_shell="$SHELL_ROLE_DEVELOPER"
            account_expiry_days=""
            sudo_access="${sudo_access:-allow}"
            echo "INFO: Applied 'developer' role defaults"
            return 0
            ;;
        support)
            user_shell="$SHELL_ROLE_SUPPORT"
            account_expiry_days=""
            sudo_access="${sudo_access:-deny}"
            echo "INFO: Applied 'support' role defaults"
            return 0
            ;;
        intern)
            user_shell="$SHELL_ROLE_INTERN"
            account_expiry_days="$ACCOUNT_EXPIRY_INTERN"
            sudo_access="${sudo_access:-deny}"
            echo "INFO: Applied 'intern' role defaults"
            return 0
            ;;
        manager)
            user_shell="$SHELL_ROLE_MANAGER"
            account_expiry_days=""
            sudo_access="${sudo_access:-deny}"
            echo "INFO: Applied 'manager' role defaults"
            return 0
            ;;
        contractor)
            user_shell="$SHELL_ROLE_CONTRACTOR"
            account_expiry_days="$ACCOUNT_EXPIRY_CONTRACTOR"
            sudo_access="${sudo_access:-deny}"
            echo "INFO: Applied 'contractor' role defaults"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

get_shell_from_role() {
    local role="$1"
    
    case "$role" in
        admin) echo "$SHELL_ROLE_ADMIN" ;;
        developer) echo "$SHELL_ROLE_DEVELOPER" ;;
        support) echo "$SHELL_ROLE_SUPPORT" ;;
        intern) echo "$SHELL_ROLE_INTERN" ;;
        manager) echo "$SHELL_ROLE_MANAGER" ;;
        contractor) echo "$SHELL_ROLE_CONTRACTOR" ;;
    esac
}

get_expiry_days_from_role() {
    local role="$1"
    
    case "$role" in
        admin|developer|support|manager)
            echo ""
            ;;
        intern)
            echo "$ACCOUNT_EXPIRY_INTERN"
            ;;
        contractor)
            echo "$ACCOUNT_EXPIRY_CONTRACTOR"
            ;;
    esac
}

calculate_expiry_date() {
    local expiry_value="$1"
    
    if [[ "$expiry_value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "$expiry_value|$expiry_value"
    elif [[ "$expiry_value" =~ ^[0-9]+$ ]]; then
        if [ "$expiry_value" -eq 0 ]; then
            echo "|never"
        else
            local date=$(date -d "+${expiry_value} days" +%Y-%m-%d)
            echo "$date|$expiry_value days (on $date)"
        fi
    elif is_valid_role "$expiry_value"; then
        local days=$(get_expiry_days_from_role "$expiry_value")
        if [ -z "$days" ]; then
            echo "|never (role: $expiry_value)"
        else
            local date=$(date -d "+${days} days" +%Y-%m-%d)
            echo "$date|$days days (on $date, role: $expiry_value)"
        fi
    else
        return 1
    fi
}