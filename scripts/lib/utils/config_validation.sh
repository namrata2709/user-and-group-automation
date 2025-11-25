#!/usr/bin/env bash
# ===============================================
# Configuration Validation Module
# Version: 1.0.1
# ===============================================

validate_config() {
    local errors=0
    local warnings=0
    
    # Validate DEFAULT_PASSWORD
    if [ -n "$DEFAULT_PASSWORD" ]; then
        if [ ${#DEFAULT_PASSWORD} -lt 8 ]; then
            echo "${ICON_WARNING} Config Warning: DEFAULT_PASSWORD too short (min 8 chars, current: ${#DEFAULT_PASSWORD})"
            ((warnings++))
        fi
    else
        echo "${ICON_ERROR} Config Error: DEFAULT_PASSWORD not set"
        ((errors++))
    fi
    
    # Validate PASSWORD_LENGTH
    if [ -n "$PASSWORD_LENGTH" ]; then
        if ! [[ "$PASSWORD_LENGTH" =~ ^[0-9]+$ ]]; then
            echo "${ICON_ERROR} Config Error: PASSWORD_LENGTH must be numeric (current: $PASSWORD_LENGTH)"
            ((errors++))
        elif [ "$PASSWORD_LENGTH" -lt 8 ]; then
            echo "${ICON_WARNING} Config Warning: PASSWORD_LENGTH too short (min 8, current: $PASSWORD_LENGTH)"
            ((warnings++))
        fi
    fi
    
    # Validate PASSWORD_EXPIRY_DAYS
    if [ -n "$PASSWORD_EXPIRY_DAYS" ]; then
        if ! [[ "$PASSWORD_EXPIRY_DAYS" =~ ^[0-9]+$ ]]; then
            echo "${ICON_ERROR} Config Error: PASSWORD_EXPIRY_DAYS must be numeric (current: $PASSWORD_EXPIRY_DAYS)"
            ((errors++))
        fi
    fi
    
    # Validate PASSWORD_WARN_DAYS
    if [ -n "$PASSWORD_WARN_DAYS" ]; then
        if ! [[ "$PASSWORD_WARN_DAYS" =~ ^[0-9]+$ ]]; then
            echo "${ICON_ERROR} Config Error: PASSWORD_WARN_DAYS must be numeric (current: $PASSWORD_WARN_DAYS)"
            ((errors++))
        fi
    fi
    
    # Validate MIN_USER_UID
    if [ -n "$MIN_USER_UID" ]; then
        if ! [[ "$MIN_USER_UID" =~ ^[0-9]+$ ]]; then
            echo "${ICON_ERROR} Config Error: MIN_USER_UID must be numeric (current: $MIN_USER_UID)"
            ((errors++))
        fi
    fi
    
    # Validate MAX_USER_UID
    if [ -n "$MAX_USER_UID" ]; then
        if ! [[ "$MAX_USER_UID" =~ ^[0-9]+$ ]]; then
            echo "${ICON_ERROR} Config Error: MAX_USER_UID must be numeric (current: $MAX_USER_UID)"
            ((errors++))
        elif [ "$MAX_USER_UID" -le "$MIN_USER_UID" ]; then
            echo "${ICON_ERROR} Config Error: MAX_USER_UID must be greater than MIN_USER_UID"
            ((errors++))
        fi
    fi
    
    # Validate MIN_GROUP_GID
    if [ -n "$MIN_GROUP_GID" ]; then
        if ! [[ "$MIN_GROUP_GID" =~ ^[0-9]+$ ]]; then
            echo "${ICON_ERROR} Config Error: MIN_GROUP_GID must be numeric (current: $MIN_GROUP_GID)"
            ((errors++))
        fi
    fi
    
    # Validate INACTIVE_THRESHOLD_DAYS
    if [ -n "$INACTIVE_THRESHOLD_DAYS" ]; then
        if ! [[ "$INACTIVE_THRESHOLD_DAYS" =~ ^[0-9]+$ ]]; then
            echo "${ICON_ERROR} Config Error: INACTIVE_THRESHOLD_DAYS must be numeric (current: $INACTIVE_THRESHOLD_DAYS)"
            ((errors++))
        fi
    fi
    
    # Validate BACKUP_RETENTION_DAYS
    if [ -n "$BACKUP_RETENTION_DAYS" ]; then
        if ! [[ "$BACKUP_RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
            echo "${ICON_ERROR} Config Error: BACKUP_RETENTION_DAYS must be numeric (current: $BACKUP_RETENTION_DAYS)"
            ((errors++))
        fi
    fi
    
    # Validate LOG_FILE
    if [ -n "$LOG_FILE" ]; then
        local log_dir
        log_dir=$(dirname "$LOG_FILE")
        if [ ! -d "$log_dir" ]; then
            echo "${ICON_WARNING} Config Warning: Log directory doesn't exist: $log_dir (will be created)"
            ((warnings++))
        fi
    else
        echo "${ICON_ERROR} Config Error: LOG_FILE not set"
        ((errors++))
    fi
    
    # Validate BACKUP_DIR
    if [ -n "$BACKUP_DIR" ]; then
        if [ ! -d "$BACKUP_DIR" ]; then
            echo "${ICON_WARNING} Config Warning: BACKUP_DIR doesn't exist: $BACKUP_DIR (will be created)"
            ((warnings++))
        fi
    else
        echo "${ICON_ERROR} Config Error: BACKUP_DIR not set"
        ((errors++))
    fi
    
    # Validate USE_UNICODE
    if [ -n "$USE_UNICODE" ]; then
        if [[ ! "$USE_UNICODE" =~ ^(yes|no)$ ]]; then
            echo "${ICON_WARNING} Config Warning: USE_UNICODE must be 'yes' or 'no' (current: $USE_UNICODE, defaulting to yes)"
            ((warnings++))
        fi
    fi
    
    # Validate DEFAULT_SHELL
    if [ -n "$DEFAULT_SHELL" ]; then
        if [[ ! "$DEFAULT_SHELL" =~ ^(a|d|allow|deny)$ ]] && [ ! -f "$DEFAULT_SHELL" ]; then
            echo "${ICON_WARNING} Config Warning: DEFAULT_SHELL invalid (current: $DEFAULT_SHELL, use: a, d, or valid path)"
            ((warnings++))
        fi
    fi
    
    # Show summary
    if [ $errors -gt 0 ] || [ $warnings -gt 0 ]; then
        echo ""
        echo "${ICON_INFO} Config validation: $errors error(s), $warnings warning(s)"
        if [ $errors -gt 0 ]; then
            echo "${ICON_ERROR} Please fix config errors in: $CONFIG_FILE"
            return 1
        fi
    fi
    
    return 0
}