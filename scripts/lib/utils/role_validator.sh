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